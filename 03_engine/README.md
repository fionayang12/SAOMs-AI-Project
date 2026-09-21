# Engine

RSiena estimation wrapper implementing the codified playbook from a
401-network analysis by human researchers. The original lives in `legacy/` as the
reference implementation; `estimate_one.R` is the modular carve-out. The data 
interface is currently demo-specific; generalizing ingestion will be completed 
after the proposal stage of the project.

**The contract is the seam**: `estimate_one.R` speaks JSON on stdout
(see CONTRACT.md). The agent, ledger, and tests all connect at that seam and
remain outside the R code.

Playbook rules implemented here (see docs/taxonomy.md for classifications):
- Per-network deterministic seeds: `12345 + ego_spell_id`, `+10000`/attempt
- Up to 5 attempts; convergence ratio threshold 0.30
- SE screen (> 100) is *flagged, never acted on*: exclusion is a normative
  decision and the engine has no authority to make it
