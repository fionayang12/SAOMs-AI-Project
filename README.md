# SAOMs-AI-Project

AI-supervised estimation of stochastic actor-oriented models (SAOMs) across
many networks, governed by a decision taxonomy and recorded in a
judgment-audit **decision ledger**.

Prototype accompanying our Stage 1 proposal to the *Organization Science*
special issue "AI-Enabled Frontiers in Organizational Science."

## What this is

Actor-oriented network models are theoretically powerful but difficult to
apply across many networks, because each estimation involves judgment calls.
This repository contains (1) an estimation engine that applies a fixed
estimation protocol to one network at a time, (2) a supervisor agent that
manages specification and convergence decisions under an ex ante boundary
taxonomy, and (3) a decision ledger that records each decision, who made it,
and the evidence that it took effect. The ledger schema includes a field
linking consequential decisions to sensitivity results; that field will be
populated in the full study.

## For reviewers

The version submitted with the proposal is the release tagged
`stage1-submission`. The table lists the main artifacts in a suggested
reading order.

| Artifact | What it is |
|---|---|
| [`00_docs/taxonomy.md`](00_docs/taxonomy.md) | The decision taxonomy: every decision in the pipeline, classified in advance as implementation, institutional, or normative, with the rule the agent follows for each. |
| [`00_docs/decisions.md`](00_docs/decisions.md) | Design log: each choice made in building the system, with its rationale. Append-only. |
| [`00_docs/walkthrough/demo_tour.R`](00_docs/walkthrough/demo_tour.R) | Manual baseline: the three demonstration networks estimated in RSiena without the agent. |
| [`01_data/demo/`](01_data/demo) | Input data for the three demonstration networks, plus the values recorded in the earlier analysis. |
| [`03_engine/estimate_one.R`](03_engine/estimate_one.R) | Estimation engine: estimates one network under the protocol and returns JSON. |
| [`03_engine/siena_logs/`](03_engine/siena_logs) | RSiena output logs from a rerun of the demonstration; they match the ledger records. |
| [`04_agent/taxonomy.json`](04_agent/taxonomy.json) and [`04_agent/policy.py`](04_agent/policy.py) | The taxonomy in machine-readable form and the code that enforces it. |
| [`04_agent/supervisor.py`](04_agent/supervisor.py) | Supervisor agent: runs the engine, records results, escalates normative decisions, and files proposals for human sign-off. |
| [`04_agent/proposer.py`](04_agent/proposer.py) | Deterministic rules that decide what to propose; an optional language model drafts the rationale text only. |
| [`04_agent/review.py`](04_agent/review.py) | Command-line interface a researcher uses to approve or reject proposals and resolve escalations. |
| [`04_agent/queue/`](04_agent/queue) | The proposal filed for network 528644. |
| [`05_ledger/records.jsonl`](05_ledger/records.jsonl) | The decision ledger for the demonstration run (one record per line). |
| [`05_ledger/report.md`](05_ledger/report.md) | The same ledger compiled into a readable audit report. |
| [`06_meta/pool.R`](06_meta/pool.R) | Random-effects pooling code for the full study (not run on the three demonstration networks). |
| [`07_tests/`](07_tests) | Automated tests of the demonstration data and of the boundary rules. |

The three demonstration networks:

- **308631** converges on the first attempt with healthy diagnostics.
- **109049** converges on the second attempt and is flagged for low
  wave-to-wave stability (Jaccard 0.095 < 0.20); a researcher decided to
  retain it.
- **528644** converges nominally, but one parameter is numerically unstable
  (SE > 100). The agent proposed dropping career tenure; a researcher
  approved, the respecified model failed to converge under all five seeds,
  and the researcher excluded the network.

### Known limitations of the demonstration

- **Ledger gap for network 528644.** The approval of the proposal and the
  failed re-estimation were run before the review interface wrote its own
  ledger records. The ledger therefore shows the proposal as pending and
  holds the researcher's later dispositions, but no records of the approval
  or the re-estimation. Because the ledger is append-only, the gap is
  documented in `00_docs/decisions.md` (D13) instead of repaired. The failed
  attempts appear in `03_engine/siena_logs/ego_528644.txt`.
- **Language-model rationale.** The rationale text in the 528644 proposal
  was drafted by the reference language model. The software checks that the
  text names the action the rules selected, but not its wording; this text
  describes the change in the past tense although it was still pending.
- **Meta-analysis not run.** Three networks are too few to pool. The pooling
  code has been tested on a subset of the broader sample; results will be
  reported in the full study.
- **Full corpus not included.** Only the three demonstration networks are
  committed (see `01_data/README.md`).

## Quickstart (three demonstration networks)

Run all commands from the repository root. Python packages are listed in
`requirements.txt`; estimation also requires R with RSiena 1.6.6 and
jsonlite.

```bash
# 1. Run the test suite (Python only; no R required):
pytest 07_tests/

# 2. Compile the committed ledger into a readable report (no R required):
python 05_ledger/ledger.py

# 3. Estimate one network (requires R), JSON out:
Rscript 03_engine/estimate_one.R --ego 308631 --data 01_data/demo

# 4. Run the full demonstration through the supervisor agent (requires R):
python 03_engine/run_demo.py

# 5. Review the proposal queue:
python 04_agent/review.py list
```

Steps 4 and 5 append records to `05_ledger/records.jsonl` and write files to
`04_agent/queue/` in your local copy. The committed versions are the
reference run; `git checkout -- 05_ledger 04_agent/queue` restores them.

To have a language model draft proposal rationales, set `AGENT_LLM_URL` and
`AGENT_LLM_MODEL` to any OpenAI-compatible endpoint (the reference
configuration is Qwen3-14B served locally through Ollama). Without them, a
deterministic template supplies the rationale and the pipeline behaves
identically.

## Repository structure

| Folder       | Contents |
|--------------|----------|
| `00_docs/`   | Decision taxonomy, design decisions log, exhibits, walkthrough. |
| `01_data/`   | Demonstration subset (three networks). Full corpus never committed; see 01_data/README. |
| `02_ingest/` | Scripts that build network data from source files. |
| `03_engine/` | RSiena estimation wrapper implementing the estimation protocol from the earlier analysis. Reference RSiena logs are in `03_engine/siena_logs/`. |
| `04_agent/`  | Supervisor agent, policy enforcement, proposal rules, and review interface (see 04_agent/README). |
| `05_ledger/` | Decision ledger: schema, writer, report compiler. |
| `06_meta/`   | Meta-analytic pooling and sensitivity comparisons. |
| `07_tests/`  | Tests of wave construction against recorded values and of the boundary rules. |

`repo_paths.py` at the root lets the Python code import `04_agent` and
`05_ledger` under the names `agent` and `ledger` (Python package names cannot
begin with a digit; see 00_docs/decisions.md D12).

## Reproducibility notes

- Estimation seeds are deterministic per network: `base_seed = 12345 +
  ego_spell_id`, attempt offset `+10000`. Every estimation is replayable from
  the network identifier alone.
- **RSiena version matters.** Seed-level reproduction requires RSiena 1.6.6
  (see 00_docs/decisions.md D7 and D15). With that version, rerunning the
  demonstration reproduces the ledger's values exactly; the logs in
  `03_engine/siena_logs/` come from such a rerun. The demonstration
  reproduces the qualitative pattern of the earlier analysis, whose recorded
  values are in `01_data/demo/walkthrough_v8_results_rows.csv`, but not its
  exact estimates.
- R packages: RSiena 1.6.6, jsonlite (tidyverse for the walkthrough).
  Python: see `requirements.txt`.

## Citing and contributing

See [`CITATION.cff`](CITATION.cff) for how to cite this repository. To
propose a use case on other network data, or to challenge a classification
in the taxonomy, open an issue using one of the templates provided.
