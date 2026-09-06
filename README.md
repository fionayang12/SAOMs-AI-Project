# SAOMs-AI-Project

AI-supervised estimation of stochastic actor-oriented models (SAOMs) at
population scale, governed by a judgment-audit **decision ledger**.

Prototype accompanying our Stage 1 proposal to the *Organization Science*
special issue "AI-Enabled Frontiers in Organizational Science."

## What this is

Actor-oriented network models are theoretically powerful and practically
inaccessible at scale. This repository contains (1) an estimation engine that
scales SAOM estimation across many networks, (2) an agent layer that manages
specification and convergence decisions under an ex ante boundary taxonomy,
and (3) a decision ledger that records every decision, its evidence, and its
counterfactual, so that scale never comes at the expense of scrutiny.

## Quickstart (demo: three exemplar networks)

```bash
# 1. Estimate one network, JSON out:
Rscript engine/estimate_one.R --ego 308631 --data data/demo

# 2. Run the full demo (3 networks), writing ledger records:
python engine/run_demo.py

# 3. Run the test suite:
pytest tests/
```

## Repository structure

| Folder    | Contents |
|-----------|----------|
| `data/`   | Demo subset (3 networks now, 40 at submission). Full corpus never committed; see data/README. |
| `ingest/` | Scripts that build network data from source files. |
| `engine/` | RSiena estimation wrapper: the codified playbook from the 401-network analysis. |
| `agent/`  | AI supervision layer (built after engine + ledger; see agent/README). |
| `ledger/` | Decision ledger: schema, writer, report compiler. |
| `meta/`   | Meta-analytic pooling and sensitivity multiverse. |
| `docs/`   | Decision taxonomy, build decisions log, exhibits, walkthrough materials. |
| `tests/`  | Known-value tests anchored to the recorded v8 results. |

## Reproducibility notes

- Estimation seeds are deterministic per network: `base_seed = 12345 +
  ego_spell_id`, attempt offset `+10000`. Every estimation in the corpus is
  replayable from the ego id alone.
- **RSiena version matters**: seed-level reproduction requires the same RSiena
  version as the original run. Record the exact version in
  `docs/decisions.md` (TODO: confirm from the v8 machine with
  `packageVersion("RSiena")`).
- R packages: RSiena, tidyverse, jsonlite. Python: see `requirements.txt`.
