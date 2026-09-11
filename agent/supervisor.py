"""Supervisor: run the engine under policy, record everything, propose, escalate.

    python -m agent.supervisor --ids 308631 109049 528644 --data data/demo

For each network: estimate (implementation record), check flags, escalate
normative conditions, and file institutional proposals in agent/queue/ for
human sign-off (agent/review.py). The supervisor never executes a
respecification itself; review.py does, against an approved proposal.
"""
import argparse, json, os, subprocess, sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from ledger.ledger import append_record, RECORDS_PATH
from agent.policy import Policy
from agent.proposer import make_proposal, TemplateProposer, OpenAICompatProposer

HERE = os.path.dirname(os.path.abspath(__file__))
QUEUE = os.path.join(HERE, "queue")

def run_engine(ego, data_dir, engine_cmd=None, drop=None):
    cmd = list(engine_cmd or ["Rscript", "engine/estimate_one.R"])
    cmd += ["--ego", str(ego), "--data", data_dir]
    if drop:
        cmd += ["--drop", drop]
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        raise RuntimeError(f"engine failed for {ego}: {r.stderr[-500:]}")
    s = r.stdout
    start, end = s.find("{"), s.rfind("}")
    if start == -1 or end == -1:
        raise RuntimeError(f"engine returned no JSON for {ego}: "
                           f"stdout={s[:300]!r} stderr={r.stderr[-300:]!r}")
    return json.loads(s[start:end + 1])

def supervise_one(ego, data_dir, pol, proposer, engine_cmd=None,
                  records_path=RECORDS_PATH, queue_dir=QUEUE):
    out = run_engine(ego, data_dir, engine_cmd)
    last = out["attempts"][-1]

    pol.check_execute("estimate_with_retry", actor="rule")
    append_record(ego_spell_id=ego, decision_node="estimate_with_retry",
                  boundary_class="implementation", actor="rule",
                  action=f"estimated; status={out['final']['status']} on attempt {last['attempt']}",
                  evidence={"attempts": out["attempts"],
                            "software": out.get("software"),
                            "spec": out.get("spec")},
                  records_path=records_path)

    flags = out["final"].get("flags", {})
    actions = []

    if flags.get("jaccard_below_020"):
        append_record(ego_spell_id=ego, decision_node="retain_low_jaccard_network",
                      boundary_class="normative", actor="agent",
                      action="ESCALATED: Jaccard below 0.20; retention or exclusion requires human disposition",
                      evidence={"jaccard": out["descriptives"].get("jaccard")},
                      escalation_status="pending", records_path=records_path)
        actions.append("escalated:low_jaccard")

    if flags.get("se_screen_tripped"):
        append_record(ego_spell_id=ego, decision_node="exclude_unstable_network",
                      boundary_class="normative", actor="agent",
                      action="ESCALATED: SE screen tripped; exclusion requires human disposition",
                      evidence={"max_se": last.get("max_se")},
                      escalation_status="pending", records_path=records_path)
        actions.append("escalated:se_screen")

        prop = make_proposal(out, pol=pol, proposer=proposer)
        if prop is not None:
            os.makedirs(queue_dir, exist_ok=True)
            ppath = os.path.join(queue_dir, prop["proposal_id"] + ".json")
            with open(ppath, "w") as f:
                json.dump(prop, f, indent=2)
            append_record(ego_spell_id=ego, decision_node="drop_peripheral_effect",
                          boundary_class="institutional", actor="agent",
                          action=f"PROPOSED: drop {prop['proposed_action']['drop']} and re-estimate; awaiting sign-off",
                          proposal=prop["rationale"],
                          evidence=prop["evidence"],
                          escalation_status="pending", records_path=records_path)
            actions.append(f"proposed:{prop['proposal_id']}")

    return out, actions

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--ids", nargs="+", type=int, required=True)
    ap.add_argument("--data", default="data/demo")
    ap.add_argument("--llm-url", default=os.environ.get("AGENT_LLM_URL", ""))
    ap.add_argument("--llm-model", default=os.environ.get("AGENT_LLM_MODEL", ""))
    a = ap.parse_args()
    proposer = (OpenAICompatProposer(a.llm_url, a.llm_model)
                if a.llm_url and a.llm_model else TemplateProposer())
    pol = Policy()
    for ego in a.ids:
        print(f"=== network {ego} ===")
        out, actions = supervise_one(ego, a.data, pol, proposer)
        last = out["attempts"][-1]
        print(f"  status: {out['final']['status']}; conv_ratio={last.get('conv_ratio'):.3f}; "
              f"max_se={last.get('max_se'):.1f}")
        for act in actions:
            print(f"  -> {act}")
    print("\nPending items: python -m agent.review list")

if __name__ == "__main__":
    main()
