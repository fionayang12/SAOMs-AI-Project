# Data

## Policy (agreed; see 00_docs/decisions.md)

1. **Demo subset (committed):** derived network CSVs for the exemplar
   networks. USPTO-derived, public-domain source, small. Currently the three
   walkthrough networks.
2. **Full corpus (never committed):** the 401-network derived files stay
   outside the repository. Scripts in `02_ingest/` document how they are built.
3. **Raw USPTO bulk files (never committed):** build scripts only.

## demo/ contents

| File | Description |
|------|-------------|
| `walkthrough_edgelist.csv` | Co-inventing ties: ego_spell_id, year, inv1_code, inv2_code, stratum |
| `walkthrough_node_attributes.csv` | Inventor attributes: inv_code, is_newcomer, careertenure, network_constraint, inventor_degree |
| `walkthrough_v8_results_rows.csv` | Recorded v8 estimates/SEs for the demo networks (test anchors) |
| `walkthrough_focal_map.csv` | Focal newcomer spot-check map |

Exemplars: **308631** (Case A, clean), **109049** (Case B, marginal),
**528644** (Case C, nominal convergence, SE screen tripped, excluded).
