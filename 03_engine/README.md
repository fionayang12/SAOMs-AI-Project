# RSiena estimation wrapper

`estimate_one.R` is an R script that runs the RSiena network estimation procedure for one network. It implements the estimation rules developed by the human researchers in the 401-network analysis.

The original R code is preserved in `legacy/` as a reference implementation. `estimate_one.R` is a standalone version extracted from the original code and adapted to work with the demonstration data. A more general data-ingestion system will be developed after the proposal stage.

# How this script connects to the rest of the project

The R script communicates with the rest of the system through a JSON input/output format. The expected format is documented in `CONTRACT.md`.

This JSON interface serves as the connection point between the R estimation code and the other components of the project, including the AI agent, decision ledger, and automated tests. Keeping this interface separate means that those components can interact with the estimation procedure without modifying the R code itself.

# Estimation rules implemented here

The script follows the estimation protocol (see 00_docs/taxonomy.md for how each decision is classified):

- Per-network deterministic seeds: `12345 + ego_spell_id`, `+10000`/attempt
- Up to 5 attempts; convergence ratio threshold 0.30
- SE screen (> 100) is *flagged, never acted on*: exclusion is a normative
  decision and the engine has no authority to make it

`siena_logs/` contains RSiena output logs from a rerun of the demonstration; their seeds, convergence ratios, and standard errors match the ledger. The log for network 528644 also contains the five attempts to estimate the respecified model (CareerTenure dropped), none of which completed.

`run_demo.py` runs the three demonstration networks through the supervisor agent (`04_agent/supervisor.py`).

RSiena writes its output log to the current working directory. Therefore, if you run the estimation script from the repository root, RSiena will create files such as `ego_*.txt` there (the root
`.gitignore` keeps them out of commits).
