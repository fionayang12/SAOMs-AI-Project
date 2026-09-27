"""Map the numbered folders to importable Python package names.

The folders are numbered in the order a reviewer reads them (see
00_docs/decisions.md D12). Python cannot import a package whose name starts
with a digit, so this module registers the two Python packages under their
working names:

    04_agent   ->  agent
    05_ledger  ->  ledger

Entry points import this module once, after putting the repository root on
sys.path; every other import in the code (e.g. `from ledger.ledger import
append_record`) then works unchanged.
"""
import importlib.util
import os
import sys

ROOT = os.path.dirname(os.path.abspath(__file__))
PACKAGES = {"agent": "04_agent", "ledger": "05_ledger"}

for name, folder in PACKAGES.items():
    if name in sys.modules:
        continue
    path = os.path.join(ROOT, folder)
    spec = importlib.util.spec_from_file_location(
        name, os.path.join(path, "__init__.py"),
        submodule_search_locations=[path])
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
