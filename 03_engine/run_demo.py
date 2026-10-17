"""Run the three-network demonstration through the supervisor agent.

    python 03_engine/run_demo.py            (run from the repository root)

This is a convenience wrapper for
    python 04_agent/supervisor.py --ids 308631 109049 528644 --data 01_data/demo
Any further arguments (for example --llm-url and --llm-model) are passed on to
the supervisor. The supervisor estimates each network, writes ledger records,
escalates normative decisions to a human, and files institutional proposals in
04_agent/queue/ for sign-off through 04_agent/review.py.

An earlier version of this script wrote the low-Jaccard retention for network
109049 directly as a resolved human disposition. It was replaced by this
wrapper so that every run follows the same boundary rules as the supervisor
(00_docs/decisions.md D15).
"""
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CASES = [308631, 109049, 528644]


def main():
    cmd = [sys.executable, os.path.join(ROOT, "04_agent", "supervisor.py"),
           "--ids", *[str(c) for c in CASES], "--data", "01_data/demo",
           *sys.argv[1:]]
    return subprocess.call(cmd, cwd=ROOT)


if __name__ == "__main__":
    sys.exit(main())
