# Analysis

The study produces **two halves of one dataset**, and neither is complete on its own:

- **this app** — one session per participant, each holding four writing runs plus the
  fifth modification run, with the Likert answers per run
- **the upstream tool** — one row per participant with the demographics (age, gender,
  occupation, …)

They are joined on **`CASE` (SoSci) ↔ `case_number` (this app)** — the interview number the
entry link carried as `%case%`. Not on `case_id`: that token has no column in the SoSci
export, see [`sosci/README.md`](sosci/README.md#join-key).

## Layout

```
analysis          this directory
  /               the merge + analysis scripts
  /data/raw/      frozen input snapshots
  /data/derived/  generated tables
```

## Merging

```sh
Rscript merge_study_data.R      # or source("merge_study_data.R") in RStudio
```

Reads the two snapshots from `data/raw/` and writes `data/derived/`. Every table is written
twice — `.csv` to look at or hand on (factors become their German labels), `.rds` for R
(factor levels, `POSIXct` and attributes survive intact).

| File | One row per | What it is |
|---|---|---|
| `01_nur_sosci` | participant | Only in SoSci — questionnaire started, but no app session. |
| `02_nur_app` | participant | Only in the app — session without a matching SoSci row. Empty when the data is consistent, but always written. |
| `03_matched` | participant | In both, unfiltered, with the exclusion flags. |
| `04_eingeschlossen` | participant | The analysis sample at participant level — matched, no exclusion criterion hit. |
| `05_ausgeschlossen` | participant | Matched but excluded; `ausschlussgrund` names which criterion. |
| `06_zusammengefuehrt` | participant × run | **The analysis table.** 5 rows per participant (4 writing + 1 modification) with demographics and session fields attached — the long format `lmerTest` expects. `kind` separates writing from modification, `run_pos` gives the 1–5 order. |
| `07_lesbar.csv` | participant × run | `06` with readable headers — `Consent` instead of `SC01`, `Ownership: Urheberschaft` instead of `likert_authorship`. For reading, sharing and the appendix; CSV only, since headers with spaces and colons are awkward in R. |
| `07a`–`07f` | participant × run | `07` split up: `a`–`d` are the four cells of the 2×2 design (49 rows each), `e` is the modification run, `f` is all writing runs (196 = `07` without `e`). Same columns and headers as `07` throughout, so they stack back together. |
| `transcripts_long` | participant × run × turn | The transcripts. Separate because stacking them into `06` would triple every Likert value. |
| `teilnehmerfluss.csv` | flow stage | CONSORT-style counts from raw rows to analysis sample, one row per exclusion criterion. |
| `variablen_labels.csv` | variable | `SD01 → "Geschlecht"` etc., harvested from the SoSci codebook. |

### Exclusion criteria

They live in `EXCLUSION_CRITERIA` at the top of `merge_study_data.R`:

```r
EXCLUSION_CRITERIA <- list(
  sc02_leer     = quo(is.na(SC02)),
  nicht_beendet = quo(!FINISHED %in% TRUE)
)
```

One entry = one criterion; adding a line is enough. Each one automatically gets its own
`ex_<name>` column, appears in `ausschlussgrund`, gets a row in `teilnehmerfluss.csv` and
a readable header in `07_lesbar.csv`.
The expressions are evaluated on the matched dataset and may use SoSci columns (`SC02`,
`FINISHED`, `TIME_SUM`, …) as well as app columns (`session_status`, `n_runs`, …); a
criterion whose columns are missing is skipped rather than failing.

### Readable headers

`07_lesbar.csv` takes its column names from the SoSci codebook itself (the `comment()`
attributes the import script sets), so they stay current across a re-export. Two tables at
the top of `merge_study_data.R` fill the gaps:

- `COLUMN_LABELS_APP` — everything the codebook does not know: the app export and the
  derived columns.
- `COLUMN_LABELS_OVERRIDE` — codebook labels unusable as a header, either because they are
  whole sentences (`LASTPAGE`) or carry input hints (`SD02_01`). It also fixes the codebook's
  own typo in `SD08` ("Kreatvies Schreiben").

A column with no entry keeps its technical name and is reported on the console; two columns
mapping to the same header abort the run.

### The 07a–f split

`SUBSET_FILES`, also at the top of the script, defines one entry per file — a filter and a
description. The filters run against the technical table, not the readable one, so renaming
a column in `COLUMN_LABELS_APP` cannot silently break them; `readable_names()` is applied
afterwards, which is why every subset has byte-identical headers to `07`.

`a`–`d` cut by **condition**, not by position in the sequence. Run order is randomised, so
cutting by `run_pos` would put all four conditions into every file — `run_pos` stays a
column instead, which keeps order effects available. The script asserts that `a+b+c+d`
equals `f` and that `e+f` equals `07`, so a typo in a filter fails the run rather than
quietly dropping rows.

## Getting the data

Pull this app's half from prod straight into the snapshot directory (see the
[export section](../README.md#exporting-study-data) of the root README for what
`bin/export.sh` does and what the selectors mean):

```sh
./bin/export.sh all analysis/data/raw/export_$(date +%F).json
```

Place the upstream tool's export next to it, dated the same way. Both files are
**snapshots**: once exported they are treated as read-only inputs, so that every derived
number can be traced back to a fixed state of the data.
