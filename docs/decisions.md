# Build decisions log

Format: ID | date | decision | rationale. Append; never rewrite history.

- **D1** | 2026-09 | Per-network deterministic seeds: `12345 + ego_spell_id`,
  `+10000` per attempt (carried over from the v8 run). | Every estimation is
  replayable from the ego id alone; stronger reproducibility than a global seed.
- **D2** | 2026-09 | Python orchestration calls R via `Rscript` subprocess
  with a JSON contract (engine/CONTRACT.md); no rpy2. | Debuggability; clean
  seam for agent, ledger, and tests; plays to team language strengths.
- **D3** | 2026-09 | Every intervention must emit evidence it took effect;
  the ledger records evidence, not intentions. | The v8 seed bug: modifying
  `algo$seed` after creation was silently ignored; five "different" attempts
  were identical until `sienaAlgorithmCreate` moved inside the retry loop.
- **D4** | 2026-09 | Thresholds carried from v8: convergence ratio < 0.30,
  max 5 attempts, SE screen > 100. Threshold *changes* are
  institutional-boundary decisions, versioned here. | Continuity with the
  validated run.
- **D5** | 2026-09 | Data policy: demo derived data committed; full corpus
  and raw bulk files never committed (see data/README.md). | Reproducibility
  with restraint; repo stays small and public-safe.
- **D6** | OPEN | Ledger schema freeze (v0.1 drafted in ledger/schema.json).
  | Pressure-test against the three walkthrough cases, then freeze.
- **D7** | OPEN | Record the exact RSiena version of the v8 run
  (`packageVersion("RSiena")` on the analysis machine); pin in renv. |
  Seed-level reproduction requires it.
- **D8** | OPEN | Agent model selection (open-weight reference
  configuration) and hardware assignment. | Access-requirements section of
  the technical appendix depends on this.
