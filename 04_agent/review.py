"""Sign-off interface for institutional proposals.

    python -m agent.review list
    python -m agent.review show prop-528644-drop-CareerTenure
    python -m agent.review approve prop-528644-drop-CareerTenure \
        --by "M. Howard" --note "Peripheral effect; precedent applies."
    python -m agent.review reject  <id> --by NAME --note REASON

Approval executes the re-estimation under the approved proposal, records the
evidence, and then escalates admission of the respecified network as a NEW
normative decision: sign-off on the respecification is not admission into
the pooled sample.
"""
import argparse, json, os, sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from ledger.ledger import append_record, RECORDS_PATH
from agent.policy import Policy
from agent.supervisor import run_engine, QUEUE

def _load(pid, queue_dir):
    path = os.path.join(queue_dir, pid + ".json")
    if not os.path.exists(path):
        sys.exit(f"No such proposal: {pid}")
    with open(path) as f:
        return json.load(f), path

def cmd_list(queue_dir):
    if not os.path.isdir(queue_dir):
        print("Queue empty."); return
    for fn in sorted(os.listdir(queue_dir)):
        if fn.endswith(".json"):
            with open(os.path.join(queue_dir, fn)) as f:
                p = json.load(f)
            print(f"{p['proposal_id']:40s} {p['status']:9s} ego={p['ego']}")

def cmd_show(pid, queue_dir):
    p, _ = _load(pid, queue_dir)
    print(json.dumps(p, indent=2))

def cmd_approve(pid, by, note, data_dir, queue_dir, records_path, engine_cmd=None):
    p, path = _load(pid, queue_dir)
    if p["status"] != "pending":
        sys.exit(f"Proposal is {p['status']}, not pending.")
    p["status"] = "approved"; p["disposed_by"] = by; p["disposition_note"] = note
    with open(path, "w") as f:
        json.dump(p, f, indent=2)

    pol = Policy()
    pol.check_execute("drop_peripheral_effect", actor="agent", approved_proposal=p)
    append_record(ego_spell_id=p["ego"], decision_node="drop_peripheral_effect",
                  boundary_class="institutional", actor="human",
                  action=f"APPROVED proposal {pid}: drop {p['proposed_action']['drop']}",
                  proposal=p["rationale"], human_disposition=f"{by}: {note}",
                  escalation_status="resolved", records_path=records_path)

    out = run_engine(p["ego"], data_dir, engine_cmd, drop=p["proposed_action"]["drop"])
    last = out["attempts"][-1]
    append_record(ego_spell_id=p["ego"], decision_node="estimate_with_retry",
                  boundary_class="implementation", actor="rule",
                  action=(f"re-estimated under approved {pid}; "
                          f"status={out['final']['status']} on attempt {last['attempt']}"),
                  evidence={"attempts": out["attempts"], "spec": out.get("spec")},
                  counterfactual_ref=pid, records_path=records_path)

    append_record(ego_spell_id=p["ego"], decision_node="admit_respecified_network",
                  boundary_class="normative", actor="agent",
                  action=("ESCALATED: respecified estimates available; admission "
                          "to the pooled sample requires human disposition with "
                          "sensitivity report"),
                  evidence={"respec_status": out["final"]["status"],
                            "respec_max_se": last.get("max_se"),
                            "dropped": out.get("spec", {}).get("dropped")},
                  escalation_status="pending", records_path=records_path)
    ms = last.get("max_se")
    ms_txt = f"{ms:.1f}" if ms is not None else f"n/a (attempt error: {last.get('error', 'unknown')})"
    print(f"Approved and re-estimated: status={out['final']['status']}, max_se={ms_txt}.")
    print("Admission to the pooled sample is now a pending normative decision.")
    return out

def cmd_resolve(ego, node, by, note, records_path):
    """Record a human disposition for a pending normative escalation.

    Append-only: the original pending record stays; this adds the resolved
    record for the same (ego, node), which the report treats as closing it.
    """
    pol = Policy()
    cls = pol.node_class(node)          # also validates the node exists
    if cls != "normative":
        sys.exit(f"'{node}' is {cls}; resolve is for normative escalations "
                 f"(institutional proposals go through approve/reject).")
    append_record(ego_spell_id=ego, decision_node=node,
                  boundary_class="normative", actor="human",
                  action="RESOLVED: human disposition recorded",
                  human_disposition=f"{by}: {note}",
                  escalation_status="resolved", records_path=records_path)
    print(f"Resolved {node} for {ego} and recorded the disposition.")

def cmd_reject(pid, by, note, queue_dir, records_path):
    p, path = _load(pid, queue_dir)
    p["status"] = "rejected"; p["disposed_by"] = by; p["disposition_note"] = note
    with open(path, "w") as f:
        json.dump(p, f, indent=2)
    append_record(ego_spell_id=p["ego"], decision_node="drop_peripheral_effect",
                  boundary_class="institutional", actor="human",
                  action=f"REJECTED proposal {pid}",
                  human_disposition=f"{by}: {note}",
                  escalation_status="resolved", records_path=records_path)
    print("Rejected and recorded.")

def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    sub.add_parser("list")
    s = sub.add_parser("show"); s.add_argument("pid")
    for name in ("approve", "reject"):
        s = sub.add_parser(name)
        s.add_argument("pid"); s.add_argument("--by", required=True)
        s.add_argument("--note", required=True)
        if name == "approve":
            s.add_argument("--data", default="data/demo")
    s = sub.add_parser("resolve")
    s.add_argument("--ego", type=int, required=True)
    s.add_argument("--node", required=True)
    s.add_argument("--by", required=True); s.add_argument("--note", required=True)
    a = ap.parse_args()
    if a.cmd == "list":
        cmd_list(QUEUE)
    elif a.cmd == "show":
        cmd_show(a.pid, QUEUE)
    elif a.cmd == "approve":
        cmd_approve(a.pid, a.by, a.note, a.data, QUEUE, RECORDS_PATH)
    elif a.cmd == "reject":
        cmd_reject(a.pid, a.by, a.note, QUEUE, RECORDS_PATH)
    elif a.cmd == "resolve":
        cmd_resolve(a.ego, a.node, a.by, a.note, RECORDS_PATH)

if __name__ == "__main__":
    main()
