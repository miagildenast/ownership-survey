# Reasoning-Tokens & die System-Preamble (LM Studio)

Warum die ping-pong-Antworten zu schnell und zu stumpf waren — und der Fix.

## Symptom

App-Antworten kamen instant und flach, während ein nackter `curl` gegen
dasselbe LM-Studio-Modell deutlich länger brauchte und bessere Zeilen lieferte.
Ursache: die globale System-Preamble (`OwnershipAshChat.LLM.@system_preamble`)
hat das Reasoning des Modells unterdrückt.

## Curl zum Nachstellen

Beide Requests sind identisch — nur die `system`-Message unterscheidet sich.

### Alt — killt Reasoning

```bash
curl -s http://localhost:1234/v1/chat/completions -H "Content-Type: application/json" -d '{
  "model":"google/gemma-4-e4b",
  "messages":[
    {"role":"system","content":"You are a text generation component used in a scientific experiment.\nFollow the instructions exactly.\nOutput only the requested text.\nNever provide explanations, comments, formatting notes, or additional content.\nThe output language is German unless explicitly stated otherwise.\n"},
    {"role":"user","content":"Generate the second line of a German haiku.\nFirst line:\n„Stille am Teich“\nConstraints:\n„Output exactly one line.“\n„The line must contain 7 syllables.“\n„Output language: German.“\n„Do not add quotation marks.“\n„Do not add explanations.“\n„Do not add any text before or after the line.“\nReturn only the second line.\n"}
  ]
}' | jq '{content: .choices[0].message.content, reasoning_tokens: .usage.completion_tokens_details.reasoning_tokens}'
```

**Erwartet:** `reasoning_tokens: 0`, content stumpf, Antwort fast instant.

### Neu — Reasoning an

```bash
curl -s http://localhost:1234/v1/chat/completions -H "Content-Type: application/json" -d '{
  "model":"google/gemma-4-e4b",
  "messages":[
    {"role":"system","content":"You are a text generation component used in a scientific experiment.\nFollow the instructions exactly.\nYour FINAL answer must contain only the requested text — no explanations,\ncomments, formatting notes, or additional content.\nYou may reason internally before producing the final answer; that reasoning\nis not part of the final answer.\nThe output language is German unless explicitly stated otherwise.\n"},
    {"role":"user","content":"Generate the second line of a German haiku.\nFirst line:\n„Stille am Teich“\nConstraints:\n„Output exactly one line.“\n„The line must contain 7 syllables.“\n„Output language: German.“\n„Do not add quotation marks.“\n„Do not add explanations.“\n„Do not add any text before or after the line.“\nReturn only the second line.\n"}
  ]
}' | jq '{content: .choices[0].message.content, reasoning_tokens: .usage.completion_tokens_details.reasoning_tokens}'
```

**Erwartet:** `reasoning_tokens: ~400–600`, content eine saubere deutsche Zeile,
Antwort dauert spürbar länger.

## Was sind `reasoning_tokens`?

Tokens, die das Modell für seinen **internen Denk-Block** verbraucht, bevor es
die finale Antwort schreibt. Bei einem Reasoning-Modell (gemma-4 mit aktiviertem
Thinking) läuft eine Generation in zwei Phasen:

1. **Think-Phase** → versteckte Überlegung (Silben zählen, Varianten abwägen).
   Geht ins separate Feld `reasoning_content`, gezählt als `reasoning_tokens`.
2. **Answer-Phase** → finaler Text. Geht in `content`.

- `reasoning_tokens: 0` → Phase 1 übersprungen. Modell rät die Zeile direkt
  (schnell, schlechter).
- `reasoning_tokens > 0` → Modell hat gedacht (langsamer, besser).

In ReqLLM landet `reasoning_content` in `:thinking`-Chunks und ist **nicht** Teil
von `ReqLLM.Response.text/1` (das gibt nur `:content`). Das Reasoning verschmutzt
also nie `final_haiku` — kein `<think>`-Stripping nötig.

## Warum killt der Prompt das Reasoning?

Die alte Preamble enthielt zwei absolute Anweisungen:

```
Output only the requested text.
Never provide explanations, comments, formatting notes, or additional content.
```

Der Denk-Block ist aus Modellsicht „additional content" / eine „explanation".
Ein instruktionstreues Modell befolgt das wörtlich und **lässt die Think-Phase
ganz weg** → `reasoning_tokens: 0`.

Beweis durch Isolation:

| Variante                                            | reasoning_tokens |
| --------------------------------------------------- | ---------------- |
| Alte Preamble + voller User-Prompt                  | **0**            |
| Kein System, voller User-Prompt                     | 676              |
| Gelockerte Preamble + voller User-Prompt            | 432–561          |

Die `Do not add explanations`-Zeilen **im User-Prompt** sind unschuldig (mittlere
Zeile: 676). Allein der Preamble-Wortlaut war der Auslöser.

## Fix

Preamble so umformuliert, dass die Einschränkung nur die **finale Antwort**
betrifft und internes Reasoning ausdrücklich erlaubt ist
(`lib/ownership_ash_chat/llm.ex`):

```
Your FINAL answer must contain only the requested text — no explanations,
comments, formatting notes, or additional content.
You may reason internally before producing the final answer; that reasoning
is not part of the final answer.
```

Finaler Output bleibt sauber, Reasoning ist wieder an.
