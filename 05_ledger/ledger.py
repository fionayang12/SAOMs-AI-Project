"""Decision ledger: validated append + report compilation."""
import json, os, uuid, datetime

HERE = os.path.dirname(os.path.abspath(__file__))
SCHEMA_PATH = os.path.join(HERE, "schema.json")
RECORDS_PATH = os.path.join(HERE, "records.jsonl")

with open(SCHEMA_PATH) as f:
    SCHEMA = json.load(f)
_CLASSES = SCHEMA["properties"]["boundary_class"]["enum"]
_ACTORS  = SCHEMA["properties"]["actor"]["enum"]

def append_record(decision_node, boundary_class, actor, action,
                  ego_spell_id=None, proposal=None, evidence=None,
                  escalation_status="none", human_disposition=None,
                  counterfactual_ref=None, records_path=RECORDS_PATH):
    if boundary_class not in _CLASSES:
        raise ValueError(f"boundary_class must be one of {_CLASSES}")
    if actor not in _ACTORS:
        raise ValueError(f"actor must be one of {_ACTORS}")
    if boundary_class == "normative" and escalation_status == "none":
        raise ValueError("normative decisions must carry an escalation_status "
                         "of 'pending' or 'resolved'; they are never silent")
    rec = {
        "record_id": str(uuid.uuid4()),
        "timestamp": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "ego_spell_id": ego_spell_id,
        "decision_node": decision_node,
        "boundary_class": boundary_class,
        "actor": actor,
        "action": action,
        "proposal": proposal,
        "evidence": evidence,
        "escalation_status": escalation_status,
        "human_disposition": human_disposition,
        "counterfactual_ref": counterfactual_ref,
    }
    with open(records_path, "a") as f:
        f.write(json.dumps(rec) + "\n")
    return rec

def compile_report(records_path=RECORDS_PATH):
    if not os.path.exists(records_path):
        return "Ledger empty."
    recs = [json.loads(l) for l in open(records_path)]
    resolved = {(r.get("ego_spell_id"), r["decision_node"])
                for r in recs if r.get("escalation_status") == "resolved"}
    by_class = {}
    for r in recs:
        by_class.setdefault(r["boundary_class"], []).append(r)
    lines = [f"# Ledger report ({len(recs)} records)\n"]
    for cls in ("implementation", "institutional", "normative"):
        rs = by_class.get(cls, [])
        lines.append(f"## {cls}: {len(rs)} records")
        for r in rs:
            tag = ""
            if r["boundary_class"] == "normative" and r.get("escalation_status") == "pending":
                key = (r.get("ego_spell_id"), r["decision_node"])
                tag = ("  [resolved below]" if key in resolved
                       else "  [OPEN ESCALATION - not final]")
            lines.append(f"- {r.get('ego_spell_id','-')}: {r['decision_node']} "
                         f"({r['actor']}) {r['action']}{tag}")
        lines.append("")
    return "\n".join(lines)

if __name__ == "__main__":
    print(compile_report())
