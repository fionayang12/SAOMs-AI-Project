# Engine JSON contract (v0.1)

One command, one job, one JSON object on stdout:

```bash
Rscript engine/estimate_one.R --ego 308631 --data data/demo
```

## Output shape

```json
{
  "ego": 308631,
  "descriptives": {
    "n_inventors": 58, "n_years": 3, "n_newcomers": 13,
    "ties_w1": 200, "ties_w2": 87, "density_w1": 0.121, "jaccard": 0.3232
  },
  "attempts": [
    {"attempt": 1, "seed": 320976, "conv_ratio": 0.051,
     "max_abs_t": 0.031, "max_se": 1.68, "converged": true}
  ],
  "final": {
    "status": "converged",
    "estimates": [
      {"effect": "density", "theta": -1.702, "se": 0.11, "conv_t": 0.02}
    ],
    "flags": {"se_screen_tripped": false, "jaccard_below_020": false}
  },
  "software": {"r": "4.6.1", "rsiena": "1.4.x"}
}
```

## Rules

1. `status` is one of `converged`, `not_converged`, `error`.
2. Flags report; they never decide. A tripped SE screen or low Jaccard is
   surfaced for the agent/human layer; the engine still returns estimates.
3. Nothing is printed to stdout except the JSON (RSiena chatter goes to
   stderr or is suppressed), so callers can `json.loads` the output directly.
4. Any schema change bumps the version here and in docs/decisions.md.
