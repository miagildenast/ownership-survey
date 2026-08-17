# Analysis

The study produces **two halves of one dataset**, and neither is complete on its own:

- **this app** — one session per participant, each holding four writing runs plus the
  fifth modification run, with the Likert answers per run
- **the upstream tool** — one row per participant with the demographics (age, gender,
  occupation, …)

They are joined on the ID both sides share: `case_id` here, the value the upstream tool
substituted into the `%caseToken%` placeholder of the entry link there.

## Layout

```
analysis          this directory
  /               the merge + analysis scripts
  /data/raw/      frozen input snapshots
  /data/derived/  generated tables
```

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
