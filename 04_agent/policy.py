"""Policy layer: the boundary rules, enforced by ordinary code.

The language model never touches this module. Whatever a proposer generates,
execution passes through check_execute(), and normative nodes cannot be
executed by the agent under any input.
"""
import json, os

HERE = os.path.dirname(os.path.abspath(__file__))

class PolicyViolation(Exception):
    """Raised when an actor attempts an action its boundary class forbids."""

def load_taxonomy(path=None):
    with open(path or os.path.join(HERE, "taxonomy.json")) as f:
        return json.load(f)

class Policy:
    def __init__(self, taxonomy=None):
        self.t = taxonomy or load_taxonomy()

    def node_class(self, node):
        try:
            return self.t["nodes"][node]["class"]
        except KeyError:
            raise PolicyViolation(
                f"Unknown decision node '{node}': every action must map to a "
                f"node in taxonomy.json before it can run.")

    def check_execute(self, node, actor, approved_proposal=None):
        """Gate for any state-changing action. Returns the required record
        fields; raises PolicyViolation if the action may not proceed."""
        cls = self.node_class(node)
        rules = self.t["classes"][cls]
        if actor == "human":
            return {"boundary_class": cls}
        if cls == "implementation":
            return {"boundary_class": cls}
        if cls == "institutional":
            if approved_proposal and approved_proposal.get("status") == "approved":
                return {"boundary_class": cls,
                        "proposal_id": approved_proposal["proposal_id"]}
            raise PolicyViolation(
                f"'{node}' is institutional: the agent may propose but not "
                f"execute without an approved, recorded sign-off.")
        raise PolicyViolation(
            f"'{node}' is normative: never executed by the agent. "
            f"Escalate with evidence and wait for a human disposition.")

    def effect_drop_node(self, effect_name):
        """Classify a proposed effect drop: peripheral vs. theory-bearing."""
        eff = self.t["effects"]
        for p in eff["protected"]:
            if p.lower() in effect_name.lower():
                return "drop_theory_bearing_effect"
        for d in eff["droppable"]:
            if d.lower() in effect_name.lower():
                return "drop_peripheral_effect"
        return "drop_theory_bearing_effect"  # unknown effects default to protected
