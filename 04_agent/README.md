# Agent: the supervision layer

Runs the engine under the boundary taxonomy, records everything in the
ledger, proposes remedies at institutional nodes, and escalates normative
decisions to humans. The design commitments, now implemented:

1. **Code decides; the model narrates.** Diagnosis and proposal content are
   deterministic (`proposer.py`); a language model, when configured,
   generates the prose rationale only, and narration that names a different
   action than the decided one is discarded. The model cannot talk its way
   past a boundary because no execution path routes through it
   (`policy.py` gates every state-changing action).
2. **Configured, not hard-coded (D8).** `OpenAICompatProposer` speaks to any
   OpenAI-compatible endpoint (a local open-weight model under Ollama or
   llama.cpp). Set `AGENT_LLM_URL` and `AGENT_LLM_MODEL`, or pass
   `--llm-url/--llm-model`. Absent a model, the deterministic
   `TemplateProposer` runs and behavior is identical: the pipeline never
   depends on model availability.
3. **Sign-off is not admission.** Approving a respecification executes the
   re-estimation and records it; admitting the respecified network into the
   pooled sample is escalated as a separate normative decision.

## Usage

```bash
# Supervise networks (records + escalations + proposals):
python 04_agent/supervisor.py --ids 308631 109049 528644 --data 01_data/demo

# Review the proposal queue:
python 04_agent/review.py list
python 04_agent/review.py show prop-528644-drop-CareerTenure
python 04_agent/review.py approve prop-528644-drop-CareerTenure \
    --by "M. Howard" --note "Peripheral effect; precedent applies."
```

## Files

- `taxonomy.json`: machine-readable boundary taxonomy (mirrors
  00_docs/taxonomy.md; the prose version governs, this version executes).
- `policy.py`: enforcement. `check_execute` gates every action; normative
  nodes have no agent execution path.
- `proposer.py`: diagnosis, proposal construction, LLM adapter.
- `supervisor.py`: orchestration loop (estimate, record, escalate, propose).
- `review.py`: human sign-off CLI; approval triggers the respecification.
- `queue/`: pending and disposed proposals.

Tests: `07_tests/test_agent_policy.py` proves the boundary rules in code,
including that a protected (theory-bearing) effect never receives a drop
proposal and that rejection leaves no execution trace.
