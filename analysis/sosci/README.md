# SoSci Survey — codebook and format reference

Metadata only. **None of these files contain participant data**, which is why they are
versioned here rather than under `../data/`.

| File | What it is |
|---|---|
| `import_aiownership_2026-08-17_20-22.r` | The import script SoSci generates alongside the export. It is the authoritative contract for reading `rdata_*.csv`: column order, column types, `skip = 1`, and the value labels for every coded variable. |
| `codebook_aiownership_2026-08-17_20-22.xlsx` | Human-readable variable directory — variable name, label, response code, response label, type. |
| `example_row.tsv` | Header plus **one synthetic data row** in exactly the export's format (39 columns, tab-separated, quoted headers, numeric codes, `.` as decimal mark). A format reference — the values are invented. |

The real exports are snapshots and belong in `../data/raw/`, which is gitignored.

## Join key

**`CASE` ↔ this app's `case_number`.** The entry link carried both identifiers:

```
/start?case_id=%caseToken%&case_number=%case%
```

`%case%` is the interview number, so it lands in the `CASE` column of the export.
`%caseToken%` was stored as our `case_id` but has **no column in the export at all** —
which is why the token cannot serve as the join key even though it is the value the entry
link is named after.

The two columns that might look like candidates are not:

- **`SERIAL`** is empty throughout.
- **`REF`** is *not* empty — roughly a third of the rows carry a five-digit recruiting-panel
  reference (e.g. `21058`). It matches no `case_id` and exists for only some participants,
  so it is neither the token nor a usable key.

`CASE` ↔ `case_number`, by contrast, matches every app session exactly.

## Re-exporting from SoSci

Use the **"CSV für R"** variant (`rdata_*.csv` plus the generated `import_*.r`), not the
label variant. It writes numeric codes with a single header row. If you re-export, replace
both files here.

## Missing-value convention

SoSci codes unanswered items as `-9` and keeps them as a real value, labelled
"[NA] nicht beantwortet".
