"""The boundary rules, tested as code: what the agent may and may not do."""
import json, os, sys, tempfile
import pytest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, ROOT)

from agent.policy import Policy, PolicyViolation
from agent.proposer import make_proposal, TemplateProposer
from agent.supervisor import supervise_one
from agent import review

STUB = [sys.executable, os.path.join(ROOT, "tests", "stub_engine.py")]

def _tmp():
    d = tempfile.mkdtemp()
    return os.path.join(d, "records.jsonl"), os.path.join(d, "queue")

def _records(path):
    return [json.loads(l) for l in open(path)] if os.path.exists(path) else []

def test_agent_cannot_execute_normative():
    with pytest.raises(PolicyViolation):
        Policy().check_execute("exclude_unstable_network", actor="agent")

def test_agent_cannot_execute_institutional_without_approval():
    with pytest.raises(PolicyViolation):
        Policy().check_execute("drop_peripheral_effect", actor="agent")

def test_unknown_node_is_refused():
    with pytest.raises(PolicyViolation):
        Policy().check_execute("delete_all_networks", actor="agent")

def test_protected_effect_gets_no_drop_proposal():
    out = {"ego": 1, "final": {"estimates": [
        {"effect": "Newcomer ego x transTies", "theta": 9.0, "se": 250.0}]},
        "attempts": []}
    assert make_proposal(out, proposer=TemplateProposer()) is None

def test_supervisor_escalates_and_proposes_but_never_respecifies():
    records_path, queue = _tmp()
    out, actions = supervise_one(528644, "unused", Policy(), TemplateProposer(),
                                 engine_cmd=STUB, records_path=records_path,
                                 queue_dir=queue)
    recs = _records(records_path)
    nodes = [r["decision_node"] for r in recs]
    assert "estimate_with_retry" in nodes
    assert "exclude_unstable_network" in nodes         # normative, pending
    assert "retain_low_jaccard_network" in nodes       # normative, pending
    assert "drop_peripheral_effect" in nodes           # institutional, pending
    pend = [r for r in recs if r["boundary_class"] == "normative"]
    assert all(r["escalation_status"] == "pending" for r in pend)
    # exactly one estimation ran: the original spec; no respecification
    assert nodes.count("estimate_with_retry") == 1
    assert _records.__call__  # noqa (keep helper referenced)
    props = os.listdir(queue)
    assert props == ["prop-528644-drop-CareerTenure.json"]

def test_approval_executes_respec_and_escalates_admission():
    records_path, queue = _tmp()
    supervise_one(528644, "unused", Policy(), TemplateProposer(),
                  engine_cmd=STUB, records_path=records_path, queue_dir=queue)
    out = review.cmd_approve("prop-528644-drop-CareerTenure",
                             by="Test Reviewer", note="peripheral; precedent",
                             data_dir="unused", queue_dir=queue,
                             records_path=records_path, engine_cmd=STUB)
    assert out["spec"]["dropped"] == ["CareerTenure"]
    assert out["final"]["flags"]["se_screen_tripped"] is False
    recs = _records(records_path)
    nodes = [r["decision_node"] for r in recs]
    assert nodes.count("estimate_with_retry") == 2     # original + respec
    approve = [r for r in recs if r["action"].startswith("APPROVED")]
    assert approve and approve[0]["human_disposition"].startswith("Test Reviewer")
    admit = [r for r in recs if r["decision_node"] == "admit_respecified_network"]
    assert admit and admit[0]["escalation_status"] == "pending"

def test_rejection_is_recorded_and_nothing_runs():
    records_path, queue = _tmp()
    supervise_one(528644, "unused", Policy(), TemplateProposer(),
                  engine_cmd=STUB, records_path=records_path, queue_dir=queue)
    n_before = len(_records(records_path))
    review.cmd_reject("prop-528644-drop-CareerTenure", by="Test Reviewer",
                      note="prefer exclusion", queue_dir=queue,
                      records_path=records_path)
    recs = _records(records_path)
    assert len(recs) == n_before + 1
    assert recs[-1]["action"].startswith("REJECTED")
    assert [r["decision_node"] for r in recs].count("estimate_with_retry") == 1
