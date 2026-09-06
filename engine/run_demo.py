"""Run the three-network demo through the engine and write ledger records.

This is the milestone loop: estimate -> record -> (escalate when required).
    python engine/run_demo.py
"""
import json, subprocess, sys, os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from ledger.ledger import append_record

CASES = [308631, 109049, 528644]

def main():
    for ego in CASES:
        print(f"=== network {ego} ===")
        r = subprocess.run(["Rscript", "engine/estimate_one.R",
                            "--ego", str(ego), "--data", "data/demo"],
                           capture_output=True, text=True)
        if r.returncode != 0:
            print("engine error:", r.stderr[-500:]); continue
        out = json.loads(r.stdout)
        last = out["attempts"][-1]
        # Implementation-boundary record: the estimation itself
        append_record(
            ego_spell_id=ego, decision_node="estimate_with_retry",
            boundary_class="implementation", actor="rule",
            action=f"estimated; status={out['final']['status']} on attempt {last['attempt']}",
            evidence={"attempts": out["attempts"], "software": out.get("software")},
        )
        flags = out["final"].get("flags", {})
        if flags.get("se_screen_tripped"):
            # Normative boundary: the engine flags, a human decides.
            append_record(
                ego_spell_id=ego, decision_node="exclude_unstable_network",
                boundary_class="normative", actor="agent",
                action="ESCALATED: SE screen tripped; exclusion requires human disposition",
                evidence={"max_se": last.get("max_se")},
                escalation_status="pending",
            )
            print("  -> SE screen tripped: escalated to human (see ledger)")
        print(f"  status: {out['final']['status']}; "
              f"conv_ratio={last.get('conv_ratio'):.3f}; max_se={last.get('max_se'):.1f}")
    print("\nLedger written to ledger/records.jsonl")

if __name__ == "__main__":
    main()
