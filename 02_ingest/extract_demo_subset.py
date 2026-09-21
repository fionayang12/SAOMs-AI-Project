"""Extract a self-contained demo subset from the full-corpus files.

Usage (on a machine with the full corpus):
    python ingest/extract_demo_subset.py \
        --corpus-dir "/path/to/SAOM Analysis" \
        --ids 308631 109049 528644 \
        --out data/demo
"""
import argparse, os
import pandas as pd

FILES = {
    "ego_edgelist_clean.csv": "walkthrough_edgelist.csv",
    "ego_node_attributes.csv": "walkthrough_node_attributes.csv",
    "SAOM_newcomer_results_v8.csv": "walkthrough_v8_results_rows.csv",
    "focal_newcomer_map.csv": "walkthrough_focal_map.csv",
}

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--corpus-dir", required=True)
    ap.add_argument("--ids", nargs="+", type=int, required=True)
    ap.add_argument("--out", default="data/demo")
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    for src, dst in FILES.items():
        df = pd.read_csv(os.path.join(a.corpus_dir, src))
        sub = df[df.ego_spell_id.isin(a.ids)]
        sub.to_csv(os.path.join(a.out, dst), index=False)
        print(f"{dst}: {len(sub)} rows for {sub.ego_spell_id.nunique()} networks")

if __name__ == "__main__":
    main()
