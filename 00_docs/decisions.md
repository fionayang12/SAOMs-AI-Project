# Build decisions log

Format: ID | date | decision | rationale. Append; never rewrite history.

- **D1** | 2026-09 | Per-network deterministic seeds: `12345 + ego_spell_id`,
  `+10000` per attempt (carried over from the v8 run). | Every estimation is
  replayable from the ego id alone; stronger reproducibility than a global
  seed.
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
- **D8** | 2026-09 | Reference model configuration: Qwen3 14B (Apache 2.0),
  served locally via Ollama's OpenAI-compatible endpoint
- **D9** | 2026-09 | Jaccard < 0.20 remains a FLAG, not an exclusion rule.
  The engine computes and reports it (`jaccard_below_020` in the JSON
  contract); retention or exclusion of a flagged network is always a human
  decision, escalated through the ledger. | Considered promoting the flag to
  an automatic rule; rejected because exclusion changes the analytic sample,
  which is a normative-boundary decision under the taxonomy, and because
  retroactive application would alter the published 93-network sample
  (network 109049 was retained at Jaccard 0.095). Consistency requires that
  sample-defining thresholds never execute without documentation.
- **D10** | 2026-09 | Agent architecture: code decides, the model narrates.
  Diagnosis of instability and the content of any proposal (which effect,
  which action) are determined by deterministic rules in agent/proposer.py;
  a language model, when configured, generates the prose rationale only,
  through an OpenAI-compatible adapter (reference configuration: Qwen3 14B
  via Ollama, per D8; any substitute model, or none, yields identical
  pipeline behavior). Narration is validated before use: text that fails to
  name the decided action, or arrives empty, is discarded in favor of the
  deterministic template. No execution path routes through the model, and
  agent/policy.py gates every state-changing action against the taxonomy.
  | The boundary framework requires that a model cannot talk its way past a
  boundary; the only reliable guarantee is structural. A capability
  consequence follows: model quality affects the eloquence of recorded
  rationales and nothing else, which is what makes the open-weight choice
  in D8 low-stakes for validity.
- **D11** | 2026-09 | First live integration surfaced and fixed two contract
  violations (RSiena chatter on stdout; a 1x1 matrix serialized as nested
  array) and one demo finding: the approved CareerTenure-drop respecification
  for network 528644 fails to terminate under all five seeds on both tested
  platforms, so its exclusion stands with the attempted remedy in evidence. |
  The stub validated logic but only a live consumer enforces a contract; and a
  plausible approved remedy failing in practice is the strongest available
  argument for evidence-before-admission.
- **D12** | 2026-09 | Folders renumbered in reviewer reading order:
  docs -> 00_docs, data -> 01_data, ingest -> 02_ingest, engine -> 03_engine,
  agent -> 04_agent, ledger -> 05_ledger, meta -> 06_meta, tests -> 07_tests.
  Python cannot import a package whose name begins with a digit, so
  repo_paths.py at the root registers 04_agent and 05_ledger under their
  working names (agent, ledger); entry points import it once, and all other
  imports are unchanged. Commands now run as scripts from the repository root
  (e.g. python 04_agent/supervisor.py in place of python -m agent.supervisor).
  The three RSiena output logs moved from the root to 03_engine/siena_logs/.
  | The numbered order lets a reviewer read rules, then data, then the
  pipeline in execution order, then tests. Entries D1 through D11 keep the
  original folder names as written; the mapping above translates them.
  The description field in 05_ledger/schema.json still cites docs/taxonomy.md;
  it is left unchanged because the schema is frozen at v1.0 (D6).
- **D13** | 2026-09 | Known gap in the committed demo ledger, recorded rather
  than repaired. For network 528644 the ledger holds the agent's proposal to
  drop CareerTenure (institutional, status pending), and the queue file
  04_agent/queue/prop-528644-drop-CareerTenure.json also shows it pending. The
  ledger holds no record of the human approval, the re-estimation that
  followed, or the agent's escalation of admission for the respecified
  network. The human dispositions for 528644 (exclude_unstable_network,
  admit_respecified_network) nonetheless refer to the approved respecification
  and its failure on all five seeds, and the first of them points to a
  re-estimation record that the committed ledger does not contain. The failed
  re-estimation itself is documented in D11. | The ledger is append-only, and
  records written after the fact would appear contemporaneous with the events
  they describe. The committed records stay as they are; this entry documents
  the missing records. A live approval through 04_agent/review.py writes all
  three record types, so the gap will not recur when approvals run through the
  review interface.
- **D14** | 2026-09 | Engine JSON contract documented at v0.2
  (03_engine/CONTRACT.md). The engine emits a `spec` object recording the
  specification version and any peripheral effect dropped under `--drop`;
  the ledger stores it as evidence for re-estimations. CONTRACT.md still
  described v0.1, and the version bump was not logged when the field was
  added. This entry records it. The example output now uses the recorded v8
  values for network 308631 and the pinned RSiena version (1.6.6, D7). | Rule
  4 of the contract requires the bump to be logged here. The change adds a
  field and removes none, so code written against v0.1 continues to work.
- **D15** | 2026-10 | Pre-submission corrections and release freeze.
  (a) `03_engine/run_demo.py` is now a wrapper around
  `04_agent/supervisor.py`. The earlier version wrote the low-Jaccard
  retention for network 109049 directly as a resolved human disposition, which
  bypassed the escalation path; the committed ledger was produced by the
  supervisor, not by that script. (b) Pooled estimates from the 93-network
  subset of the earlier analysis are no longer quoted in the repository
  (06_meta/README.md, the walkthrough, and the effects exhibit); they will be
  reported in the full study. (c) D9 refers to "the published 93-network
  sample"; it should read "the 93-network sample retained in the earlier
  analysis." The entry is left as written because this log is append-only.
  (d) Added a reviewer guide to the root README, CITATION.cff, issue templates
  for use cases and classification challenges, and a .gitignore (cited in
  03_engine/README.md but missing). (e) The RSiena logs in
  03_engine/siena_logs come from a rerun on 2026-10-09; their seeds,
  convergence ratios, and standard errors match the ledger records written on
  2026-09-11, and the 528644 log contains the five non-completing attempts on
  the respecified model described in D11 and D13. (f) The version submitted
  with the Stage 1 proposal is frozen as the release tagged
  `stage1-submission`. (g) D7 describes RSiena 1.6.6 as the version used
  for the v8 run. That version is not documented; 1.6.6 is the version
  pinned for this repository and used for the demonstration ledger and logs,
  which do not reproduce the exact v8 values. | Each correction aligns the repository with what it
  demonstrates and with the proposal documents; the tag gives reviewers a
  fixed version while development continues on `main`.
