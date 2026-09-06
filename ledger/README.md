# Decision ledger

The notebook that writes itself. Two jobs:

1. `append_record(...)`: validate against `schema.json`, append one line to
   `records.jsonl`. Wired in from the first day the engine runs; no
   estimation happens unrecorded.
2. `compile_report()`: fold the records into a human-readable audit summary
   (counts by boundary class, open escalations, evidence links).

Schema v0.1 is a draft pending the freeze (docs/decisions.md D6).
Normative-boundary records with `escalation_status != "resolved"` and no
`human_disposition` represent decisions that are NOT final; downstream code
must treat the affected network as undecided.
