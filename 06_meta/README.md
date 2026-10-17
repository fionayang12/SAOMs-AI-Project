# Meta-analysis

DerSimonian-Laird random-effects pooling across networks, plus the
sensitivity comparisons that feed the ledger's counterfactual hooks.

`pool.R` reproduces the pooled estimates recorded for a 93-network subset of
the earlier analysis. That check needs network-level results that are not in
the repository, so it is not part of the automated tests. Pooled results will
be reported in the full study; the pooling code is not run on the three
demonstration networks.

Usage: `Rscript 06_meta/pool.R --results <network-level results CSV> [--se-screen 100]`
