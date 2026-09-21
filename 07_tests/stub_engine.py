"""Stub engine for testing the agent layer without R/RSiena.

Mimics the JSON contract using values patterned on recorded network 528644:
without --drop, career tenure SE explodes (screen trips, Jaccard low);
with --drop CareerTenure, estimation stabilizes.
"""
import json, sys

def arg(flag, default=None):
    a = sys.argv
    return a[a.index(flag) + 1] if flag in a else default

ego = int(arg("--ego"))
drop = arg("--drop")

base = {
    "ego": ego,
    "descriptives": {"n_inventors": 48, "n_years": 3, "n_newcomers": 6,
                     "ties_w1": 147, "ties_w2": 75, "density_w1": 0.130,
                     "jaccard": 0.156},
    "spec": {"version": "v8", "dropped": [drop] if drop else []},
    "software": {"r": "stub", "rsiena": "stub"},
}
if drop == "CareerTenure":
    base["attempts"] = [{"attempt": 1, "seed": 12345 + ego, "conv_ratio": 0.19,
                         "max_abs_t": 0.08, "max_se": 2.1, "converged": True}]
    base["final"] = {"status": "converged",
                     "estimates": [{"effect": "density", "theta": -1.7, "se": 0.2, "conv_t": 0.01}],
                     "flags": {"se_screen_tripped": False, "jaccard_below_020": True}}
else:
    base["attempts"] = [{"attempt": 1, "seed": 12345 + ego, "conv_ratio": 0.219,
                         "max_abs_t": 0.09, "max_se": 133.2, "converged": True}]
    base["final"] = {"status": "converged",
                     "estimates": [
                        {"effect": "density", "theta": -1.7, "se": 0.2, "conv_t": 0.01},
                        {"effect": "CareerTenure ego", "theta": 4.1, "se": 133.2, "conv_t": 0.05}],
                     "flags": {"se_screen_tripped": True, "jaccard_below_020": True}}
print(json.dumps(base))
