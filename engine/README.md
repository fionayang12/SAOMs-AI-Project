# Engine

RSiena estimation wrapper implementing the codified playbook from the
401-network analysis (Howard). The v8 monolith lives in `legacy/` as the
reference implementation; `estimate_one.R` is the modular carve-out.

**The contract is the seam**: `estimate_one.R` speaks JSON on stdout
(see CONTRACT.md). The agent, ledger, and tests all attach at that seam and
never reach inside the R code.

Playbook rules implemented here (see docs/taxonomy.md for classifications):
- Per-network deterministic seeds: `12345 + ego_spell_id`, `+10000`/attempt
- Up to 5 attempts; convergence ratio threshold 0.30
- SE screen (> 100) is *flagged, never acted on*: exclusion is a normative
  decision and the engine has no authority to make it
