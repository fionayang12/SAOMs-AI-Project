# Agent (built after engine + ledger exist)

The supervision layer. Design commitments, agreed before any code:

1. **Boundary rules are enforced by ordinary code, not by the model.** The
   agent reads `docs/taxonomy.md` (machine-readable version to come), and the
   policy layer decides execute / propose / escalate. The language model
   generates respecification proposals and rationales *within* those rules;
   it can never talk its way past a normative boundary.
2. **Verify, then record.** Every intervention must produce evidence it took
   effect (the seed-bug lesson, docs/decisions.md D3). The ledger records
   evidence, not intentions.
3. **Open-weight first.** The reference configuration must run on models any
   researcher can obtain; a hosted-model configuration may be documented as
   an alternative.

Stage 1 scope: proposals for the institutional-boundary nodes in the
taxonomy (peripheral-effect drop, respecification suggestions), sign-off
interface, escalation queue. Everything else is Stage 2.
