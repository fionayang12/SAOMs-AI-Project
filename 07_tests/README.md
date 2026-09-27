# Tests

Known-value tests anchored to the recorded v8 results, so refactoring can
never silently change what the pipeline computes. Run with `pytest 07_tests/` from the repository root.
R-side equivalence (engine output vs. recorded estimates) is checked in the
demo run rather than pytest, keeping CI Python-only for now.
