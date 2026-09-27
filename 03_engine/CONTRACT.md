# Engine JSON contract (v0.2)

One command, one job, one JSON object on stdout:

```bash
Rscript 03_engine/estimate_one.R --ego 308631 --data 01_data/demo
Rscript 03_engine/estimate_one.R --ego 528644 --data 01_data/demo --drop CareerTenure
```

## Output shape

```json
{
  "ego": 308631,
  "descriptives": {
    "n_inventors": 58, "n_years": 3, "n_newcomers": 13,
    "ties_w1": 103, "ties_w2": 118, "density_w1": 0.062, "jaccard": 0.3234
  },
  "attempts": [
    {"attempt": 1, "seed": 320976, "conv_ratio": 0.051,
     "max_abs_t": 0.031, "max_se": 1.68, "converged": true}
  ],
  "spec": {"version": "v8", "dropped": []},
  "final": {
    "status": "converged",
    "estimates": [
      {"effect": "density", "theta": -3.031, "se": 0.484, "conv_t": 0.02}
    ],
    "flags": {"se_screen_tripped": false, "jaccard_below_020": false}
  },
  "software": {"r": "4.6.1", "rsiena": "1.6.6"}
}
```

Values are abbreviated: `estimates` lists all nine effects in actual output.

## Rules

1. `status` is one of `converged`, `not_converged`, `error`.
2. Flags report; they never decide. A tripped SE screen or low Jaccard is
   surfaced for the agent/human layer; the engine still returns estimates.
3. Nothing is printed to stdout except the JSON (RSiena chatter goes to
   stderr or is suppressed), so callers can `json.loads` the output directly.
4. Any schema change bumps the version here and in 00_docs/decisions.md.
5. `spec` records the specification version and any peripheral effect
   dropped under `--drop`. The ledger stores it as evidence with every
   re-estimation, so a respecified result is never mistaken for the
   standard specification.

## Version history

- v0.2: added `spec` (00_docs/decisions.md D14).
- v0.1: initial contract.
