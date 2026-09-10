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
- **D6** | 2026-09 | Ledger schema frozen at v1.0 (ledger/schema.json) for
  Stage 1. | The v0.1 draft was pressure-tested against the three demo
  networks and absorbed the D9 addition (a new normative node with a
  different actor, escalation state, and human disposition) without
  requiring new fields; the demo ledger now exercises every record state
  the schema defines (routine implementation, resolved normative, pending
  normative). Future schema changes are institutional-boundary decisions:
  proposed with rationale, human-approved, version-bumped, and logged here.
- **D7** | 2026-09 | RSiena version pinned: 1.6.6, the version used for the
  v8 run. Recorded here and in the root README; renv lockfile to follow
  once the R environment is captured. | Estimation is simulation-based, so
  seed-level reproduction of the recorded run requires this exact version;
  on other versions the qualitative pattern holds but exact numbers differ.
  The engine reports its RSiena version in every JSON result, so the ledger
  carries version evidence with every estimation. Replicators on a newer
  default can install the pinned version via
  remotes::install_version("RSiena", "1.6.6").
- **D8** | OPEN | Agent model selection (open-weight reference
  configuration) and hardware assignment. | Access-requirements section of
  the technical appendix depends on this.
- **D9** | 2026-09 | Jaccard < 0.20 remains a FLAG, not an exclusion rule.
  The engine computes and reports it (`jaccard_below_020` in the JSON
  contract); retention or exclusion of a flagged network is always a human
  decision, escalated through the ledger. | Considered promoting the flag to
  an automatic rule; rejected because exclusion changes the analytic sample,
  which is a normative-boundary decision under the taxonomy, and because
  retroactive application would alter the published 93-network sample
  (network 109049 was retained at Jaccard 0.095). Consistency requires that
  sample-defining thresholds never execute without documentation.
