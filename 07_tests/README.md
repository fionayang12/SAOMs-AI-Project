# Tests

Two kinds of tests, run with `pytest 07_tests/` from the repository root (no
R required):

- `test_known_values.py`: wave construction (tie counts and Jaccard index)
  for the three demonstration networks, checked against the values recorded
  in the earlier analysis, plus ledger validation rules.
- `test_agent_policy.py`: the boundary rules, using a stub engine
  (`stub_engine.py`) in place of RSiena. These tests check, for example, that
  a theory-bearing effect never receives a drop proposal, that a rejected
  proposal leaves no execution trace, and that normative decisions have no
  agent execution path.

RSiena estimates are not checked by these tests; the full study will add
checks of engine output against recorded estimates.
