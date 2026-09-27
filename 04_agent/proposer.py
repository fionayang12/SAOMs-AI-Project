"""Proposal generation: diagnose, decide by rule, narrate (optionally by LLM).

Design rule (00_docs/decisions.md D10): the *decision* about what to propose is made
by deterministic diagnosis; a language model, when configured, generates the
prose rationale only. The model narrates; code decides. If the model is
absent or unreachable, the template rationale is used and behavior is
identical. This makes D8 (model selection) a configuration choice.
"""
import json, urllib.request
from . import policy as policy_mod

SE_SCREEN = 100

def diagnose(engine_out):
    """Find the unstable parameter, if any, from an engine JSON result."""
    ests = engine_out.get("final", {}).get("estimates", [])
    bad = [e for e in ests if e.get("se") is not None and e["se"] > SE_SCREEN]
    if not bad:
        return None
    worst = max(bad, key=lambda e: e["se"])
    return {"effect": worst["effect"], "se": worst["se"]}

def template_rationale(ego, diag, drop_covariate):
    return (f"Network {ego}: parameter '{diag['effect']}' is numerically "
            f"unstable (SE = {diag['se']:.1f} > {SE_SCREEN}), indicating the "
            f"covariate lacks identifying variation in this network. "
            f"Proposal: re-estimate with {drop_covariate} removed for this "
            f"network only, preserving all theory-bearing effects. "
            f"Precedent: peripheral-effect drops are the designated first "
            f"remedy (00_docs/taxonomy.md). Cost: breaks specification "
            f"commonality for this network; the ledger records the delta.")

class TemplateProposer:
    """Deterministic proposer; the reference configuration."""
    def rationale(self, ego, diag, drop_covariate):
        return template_rationale(ego, diag, drop_covariate)

class OpenAICompatProposer:
    """Adapter for any OpenAI-compatible endpoint (e.g., a local open-weight
    model served by Ollama or llama.cpp). Configured, not hard-coded: pass
    base_url and model when D8 is resolved. Falls back to the template on
    any failure, so the pipeline never depends on model availability."""
    def __init__(self, base_url, model, timeout=30):
        self.base_url = base_url.rstrip("/"); self.model = model; self.timeout = timeout

    def rationale(self, ego, diag, drop_covariate):
        prompt = (
            "You are documenting a statistical decision that has ALREADY been "
            "made by rule. Write a 3-5 sentence rationale for the record. Do "
            "not suggest alternatives or change the action.\n"
            f"Network: {ego}. Unstable parameter: {diag['effect']} "
            f"(SE {diag['se']:.1f}, screen {SE_SCREEN}). Action: re-estimate "
            f"with covariate {drop_covariate} dropped for this network only.")
        try:
            req = urllib.request.Request(
                f"{self.base_url}/v1/chat/completions",
                data=json.dumps({"model": self.model, "max_tokens": 800,
                                 "messages": [{"role": "user", "content": prompt}]}).encode(),
                headers={"Content-Type": "application/json"})
            with urllib.request.urlopen(req, timeout=self.timeout) as r:
                out = json.load(r)
            text = out["choices"][0]["message"]["content"].strip()
            # Trim an incomplete trailing sentence (token-cap truncation).
            if text and not text.endswith((".", "!", "?")):
                cut = max(text.rfind("."), text.rfind("!"), text.rfind("?"))
                if cut > 0:
                    text = text[:cut + 1]
            # The model narrates; it never decides. Reject narration that
            # names a different action than the one decided by rule.
            if not text or drop_covariate.lower() not in text.lower():
                return template_rationale(ego, diag, drop_covariate)
            return text
        except Exception:
            return template_rationale(ego, diag, drop_covariate)

def make_proposal(engine_out, pol=None, proposer=None):
    """Return a proposal dict for an unstable network, or None.

    Routing: if the unstable effect is droppable, propose the drop
    (institutional). If it is protected, no drop is proposable; the only
    path is exclusion, which is normative and handled by the supervisor's
    escalation, not by a proposal."""
    pol = pol or policy_mod.Policy()
    proposer = proposer or TemplateProposer()
    diag = diagnose(engine_out)
    if diag is None:
        return None
    node = pol.effect_drop_node(diag["effect"])
    if node != "drop_peripheral_effect":
        return None
    drop = next(d for d in pol.t["effects"]["droppable"]
                if d.lower() in diag["effect"].lower())
    ego = engine_out["ego"]
    return {
        "proposal_id": f"prop-{ego}-drop-{drop}",
        "ego": ego,
        "node": "drop_peripheral_effect",
        "proposed_action": {"drop": drop},
        "evidence": {"unstable_effect": diag["effect"], "se": diag["se"],
                     "attempts": engine_out.get("attempts")},
        "rationale": proposer.rationale(ego, diag, drop),
        "status": "pending",
        "disposed_by": None,
        "disposition_note": None,
    }
