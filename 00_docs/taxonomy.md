# Decision taxonomy (draft v0.2)

Every decision node in the pipeline, classified ex ante. Classification
logic: **implementation** decisions have a verifiable success criterion and
change nothing about what the research claims; **institutional** decisions
are governed by field norms and need human sign-off; **normative** decisions
change what the study claims (especially who is in the analytic sample) and
are never delegated.

Contested classifications are welcome: open an issue using the
"Classification challenge" template, and the resolution is logged in
decisions.md.

| Decision node | Historical example | Class | Agent handling |
|---|---|---|---|
| Reseed a failed estimation within the attempt budget | 5 attempts, seed +10,000 each | implementation | Execute autonomously; log seed, attempt, diagnostics; verify the seed actually changed |
| Apply convergence and SE thresholds | Ratio < 0.30; SE > 100 screen | implementation | Apply and log; thresholds themselves are set by humans (see below) |
| Wave construction under the standing rule | Year 1 vs. union of years 2-3; 2-year variant | implementation | Execute per rule; flag networks near rule boundaries |
| Skip networks that cannot form two waves | 58854, 70946 (one year of data) | implementation | Execute and log; rule-based, zero discretion |
| Drop a peripheral effect to aid convergence in one network | NetworkConstraint designated first-to-drop | institutional | Propose with rationale and precedent; human signs off; ledger records both |
| Choose the standing wave design | Skip-year design rejected on Jaccard < 0.20 | institutional | Agent may surface diagnostics; design choice is human, recorded with rationale |
| Data-construction heuristics | Degree-based focal newcomer inference | institutional | Propose and apply with spot-check file generated; human reviews sample |
| Set or change global thresholds | 0.30 ratio, SE > 100, 5-attempt budget | institutional | Never changed by the agent; any change is human, versioned in the ledger |
| Exclude a nominally converged but unstable network | The v8 SE > 100 exclusion (network 528644) | normative | Always escalate; attach sensitivity report showing pooled results with and without |
| Choose between specifications with different yield | v7 (43.9%, no interactions) vs. v8 (23.3%, theory-bearing interactions) | normative | Never delegated; agent makes the tradeoff visible (side-by-side pooled results) |
| Drop a theory-bearing effect anywhere | Newcomer interactions carry the argument | normative | Always escalate, regardless of convergence benefit |
| Admit a respecified network into pooled results | Any rescue of a network like 528644 | normative | Always escalate; ledger records the specification delta and the human disposition |
| Retain or exclude a network flagged for low Jaccard (< 0.20) | 109049 retained at Jaccard 0.095 | normative | Engine flags automatically and never decides; retention or exclusion is escalated, and the disposition is recorded in the ledger (see decisions.md D9) |

The low-Jaccard case above was identified during development: the original
workflow applied the 0.20 guideline as a flag, and network 109049 was
retained despite Jaccard 0.095. Decision D9 in decisions.md confirms the
flag-not-rule classification and the rationale.
