"""Wave construction and ledger rules, anchored to recorded values."""
import json, os, sys, tempfile
import pandas as pd
import pytest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, ROOT)
import repo_paths  # noqa: F401  (maps 04_agent/05_ledger to agent/ledger)
DEMO = os.path.join(ROOT, "01_data", "demo")

from ledger.ledger import append_record

def _waves(ego):
    el = pd.read_csv(os.path.join(DEMO, "walkthrough_edgelist.csv"))
    nd = pd.read_csv(os.path.join(DEMO, "walkthrough_node_attributes.csv"))
    el = el[el.ego_spell_id == ego]; ids = set(nd[nd.ego_spell_id == ego].inv_code)
    yrs = sorted(el.year.unique())
    def ties(sub):
        s = set()
        for _, r in sub.iterrows():
            if r.inv1_code in ids and r.inv2_code in ids:
                s.add(frozenset((r.inv1_code, r.inv2_code)))
        return s
    w1 = ties(el[el.year == yrs[0]]); w2 = ties(el[el.year.isin(yrs[1:])])
    jac = len(w1 & w2) / len(w1 | w2) if (w1 | w2) else None
    return len(w1), len(w2), jac

@pytest.mark.parametrize("ego", [308631, 109049, 528644])
def test_wave_construction_matches_recorded(ego):
    rec = pd.read_csv(os.path.join(DEMO, "walkthrough_v8_results_rows.csv"))
    row = rec[rec.ego_spell_id == ego].iloc[0]
    t1, t2, jac = _waves(ego)
    assert t1 == row.ties_w1 and t2 == row.ties_w2
    assert abs(jac - row.jaccard) < 1e-3

def test_normative_records_cannot_be_silent():
    with pytest.raises(ValueError):
        append_record(decision_node="exclude_unstable_network",
                      boundary_class="normative", actor="agent",
                      action="exclude", escalation_status="none",
                      records_path=os.devnull)

def test_append_and_readback():
    with tempfile.NamedTemporaryFile(mode="w", suffix=".jsonl", delete=False) as f:
        path = f.name
    rec = append_record(decision_node="estimate_with_retry",
                        boundary_class="implementation", actor="rule",
                        action="test", ego_spell_id=308631, records_path=path)
    back = json.loads(open(path).read().strip())
    assert back["record_id"] == rec["record_id"]
    assert back["boundary_class"] == "implementation"
    os.unlink(path)
