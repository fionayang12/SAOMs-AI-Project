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
and (3) a decision ledger that records every decision of the AI engine,
its evidence, and its counterfactual.

## Start here

The folders are numbered in a suggested reading order. For a short tour:

1. `00_docs/taxonomy.md`: the decision taxonomy, which classifies every
   decision in the pipeline as implementation, institutional, or normative.
2. `00_docs/walkthrough/demo_tour.R`: a guided walk through the three
   demonstration networks.
3. `05_ledger/report.md`: the compiled ledger for the demonstration run,
   showing what was decided at each node and whether a rule, the agent, or
   a human acted.
4. `00_docs/decisions.md`: the log of build decisions and their rationales.

## Quickstart (demo: three exemplar networks)

Run all commands from the repository root.

```bash
# 1. Estimate one network, JSON out:
Rscript 03_engine/estimate_one.R --ego 308631 --data 01_data/demo

# 2. Run the full demo (3 networks), writing ledger records:
python 03_engine/run_demo.py

# 3. Run the test suite (no R required):
pytest 07_tests/
```

## Repository structure

| Folder       | Contents |
|--------------|----------|
| `00_docs/`   | Decision taxonomy, build decisions log, exhibits, walkthrough materials. |
| `01_data/`   | Demo subset (three networks). Full corpus never committed; see 01_data/README. |
| `02_ingest/` | Scripts that build network data from source files. |
| `03_engine/` | RSiena estimation wrapper: the codified playbook from the 401-network analysis. Reference RSiena logs for the demo are in `03_engine/siena_logs/`. |
| `04_agent/`  | AI supervision layer (see 04_agent/README). |
| `05_ledger/` | Decision ledger: schema, writer, report compiler. |
| `06_meta/`   | Meta-analytic pooling and sensitivity comparisons. |
| `07_tests/`  | Known-value tests anchored to the recorded v8 results, and tests of the boundary rules. |

`repo_paths.py` at the root lets the Python code import `04_agent` and
`05_ledger` under the names `agent` and `ledger` (Python package names cannot
begin with a digit; see 00_docs/decisions.md D12).

## Reproducibility notes

- Estimation seeds are deterministic per network: `base_seed = 12345 +
  ego_spell_id`, attempt offset `+10000`. Every estimation in the corpus is
  replayable from the ego id alone.
- **RSiena version matters**: Seed-level reproduction requires RSiena 1.6.6, the version used for the original run (see 00_docs/decisions.md D7).
- R packages: RSiena, tidyverse, jsonlite. Python: see `requirements.txt`.
