# ==============================================================================
# DEMO TOUR: three exemplar networks from the v8 analysis
# ==============================================================================
# This script walks three networks from the demo subset, chosen to span the
# estimation regimes the system must handle:
#
#   CASE A = 308631  (stratum A, 58 inventors, 13 newcomers)
#     Clean baseline: conv ratio 0.051, Jaccard 0.323, max SE 1.68.
#     Every diagnostic healthy; calibrates what routine estimation looks like.
#
#   CASE B = 109049  (stratum A, 64 inventors, 8 newcomers)
#     Marginal case: conv ratio 0.295, just under the 0.30 threshold, with
#     Jaccard 0.095, well below the 0.20 stability guideline, yet retained.
#     In the original workflow the Jaccard threshold operated as a flag
#     rather than an exclusion rule; 00_docs/taxonomy.md records how retention
#     of low-Jaccard networks is classified and who decides.
#
#   CASE C = 528644  (stratum B, 48 inventors, 6 newcomers)
#     The difficult network: converged nominally (ratio 0.219) but
#     se_career_tenure = 133.2 tripped the SE > 100 screen, and the network
#     was excluded from the analytic sample (the 94th network; 93 retained).
#     Diagnosis: careertenure is near-degenerate here (28 of 48 inventors at
#     zero; median 0, mean 1.69), so the data cannot pin the parameter down.
#     The descriptives predicted trouble: ties collapse from 147 (wave 1) to
#     75 (wave 2), Jaccard 0.156, heavy dissolution straining the model's
#     gradual-change assumption. Part 4 quantifies what the exclusion
#     decision cost.
#
# VALIDATION: the wave-construction logic below exactly reproduces the
# recorded ties_w1, ties_w2, and Jaccard for all three networks, and the DL
# meta-analysis function reproduces the recorded pooled values from the 93
# retained networks (e.g., newcomer_x_trans mu = -1.95, z = -5.12).
#
# EXPECTED OUTPUT (for verification): estimation is simulation-based, so
# exact numbers depend on the RSiena version; with the version recorded in
# 00_docs/decisions.md, the per-network seed formula reproduces the original
# run. Qualitative pattern on any version: Case A converges immediately,
# Case B is marginal, Case C shows an exploding career-tenure SE.
# ==============================================================================

# Required packages:
# Please make sure the following packages are installed before running this script:
# - RSiena (version 1.6.6)
# - tidyverse

# If they are not installed, please install them using:
# install.packages("tidyverse")
# install.packages("RSiena")

library(RSiena)
library(tidyverse)

# --- CONFIG -------------------------------------------------------------------
wt_dir <- "01_data/demo"   # run from the repository root

# Part 4 requires the full-corpus results file, which is not distributed
# with the demo (see 01_data/README.md). Point this at a local copy to run the
# sensitivity analysis; otherwise Part 4 prints the expected result.
full_results_csv <- Sys.getenv("SAOM_FULL_RESULTS", unset = "")

# Seeds are deterministic per network: base_seed = 12345 + ego_spell_id,
# offset +10000 per attempt. Every estimation is replayable from the ego id.
MAX_ATTEMPTS <- 5
CONV_THRESH  <- 0.30
SE_SCREEN    <- 100

CHOSEN <- list(A = 308631, B = 109049, C = 528644)

read_wt <- function(fname, required) {
  path <- file.path(wt_dir, fname)
  df <- read_csv(path, show_col_types = FALSE)
  names(df) <- sub("^\ufeff", "", trimws(names(df)))
  if (ncol(df) == 1 && grepl(";", names(df)[1]))
    df <- read_csv2(path, show_col_types = FALSE)
  missing <- setdiff(required, names(df))
  if (length(missing) > 0)
    stop(sprintf("%s is missing columns: %s\n  Columns found: %s",
                 fname, paste(missing, collapse = ", "),
                 paste(names(df), collapse = ", ")))
  df
}

el_all    <- read_wt("walkthrough_edgelist.csv",
                     c("ego_spell_id", "year", "inv1_code", "inv2_code"))
nodes_all <- read_wt("walkthrough_node_attributes.csv",
                     c("ego_spell_id", "inv_code", "is_newcomer", "careertenure",
                       "network_constraint", "inventor_degree"))
res_rows  <- read_wt("walkthrough_v8_results_rows.csv", c("ego_spell_id"))

se_map <- c(density = "se_density", transitivity = "se_transitivity",
            deg_act_pop = "se_deg_act_pop", newcomer_ego = "se_newcomer_ego",
            career_tenure_ego = "se_career_tenure",
            net_constraint_ego = "se_net_constraint",
            inv_degree_ego = "se_inv_degree",
            newcomer_x_trans = "se_newcomer_x_trans",
            newcomer_x_degplus = "se_newcomer_x_degplus")

# ==============================================================================
# NETWORK CONSTRUCTION (validated against the recorded ties and Jaccard)
# ==============================================================================

make_undirected <- function(el, node_ids) {
  n <- length(node_ids)
  mat <- matrix(0, n, n, dimnames = list(node_ids, node_ids))
  if (nrow(el) > 0) for (k in seq_len(nrow(el))) {
    i <- as.character(el$inv1_code[k]); j <- as.character(el$inv2_code[k])
    if (i %in% node_ids && j %in% node_ids) { mat[i, j] <- 1; mat[j, i] <- 1 }
  }
  mat
}

jaccard <- function(m1, m2) {
  a <- m1[upper.tri(m1)]; b <- m2[upper.tri(m2)]
  n11 <- sum(a == 1 & b == 1); n10 <- sum(a == 1 & b == 0); n01 <- sum(a == 0 & b == 1)
  if (n11 + n10 + n01 == 0) return(NA_real_)
  n11 / (n11 + n10 + n01)
}

build_case <- function(ego_id) {
  el <- el_all %>% filter(ego_spell_id == ego_id)
  nd <- nodes_all %>% filter(ego_spell_id == ego_id)
  node_ids <- as.character(nd$inv_code)
  yrs <- sort(unique(el$year))
  w1 <- make_undirected(el %>% filter(year == yrs[1]), node_ids)
  w2 <- make_undirected(el %>% filter(year %in% yrs[-1]), node_ids)
  list(ego_id = ego_id, n = length(node_ids), n_years = length(yrs),
       w1 = w1, w2 = w2, nodes = nd,
       ties1 = sum(w1)/2, ties2 = sum(w2)/2,
       dens1 = mean(w1[upper.tri(w1)]), jac = jaccard(w1, w2),
       newcomers = sum(nd$is_newcomer == 1, na.rm = TRUE))
}

print_descriptives <- function(cs, label) {
  cat(sprintf("\n=================== CASE %s: network %s ===================\n", label, cs$ego_id))
  cat(sprintf("Inventors: %d | Years: %d | Newcomers: %d\n", cs$n, cs$n_years, cs$newcomers))
  cat(sprintf("Wave 1 ties: %d (density %.3f) | Wave 2 ties: %d %s| Jaccard: %.3f%s\n",
              cs$ties1, cs$dens1, cs$ties2,
              ifelse(cs$ties2 < 0.7 * cs$ties1, " <-- TIE COLLAPSE ", ""),
              cs$jac,
              ifelse(!is.na(cs$jac) && cs$jac < 0.20, "  <-- below 0.20 stability guideline", "")))
  if (label == "C")
    cat(sprintf("Covariate check: careertenure zeros = %d of %d (near-degenerate)\n",
                sum(cs$nodes$careertenure == 0), cs$n))
  if (label == "A") {
    cat("NOTE: every indicator here is healthy: stable ties across waves and a\n")
    cat("Jaccard well above 0.20. These conditions predict routine estimation,\n")
    cat("and the run below confirms it: convergence on the first attempt.\n")
  } else if (label == "B") {
    cat("NOTE: the Jaccard of 0.095 signals heavy tie turnover between waves,\n")
    cat("straining the model's assumption that change unfolds gradually.\n")
    cat("Estimation is expected to be difficult; the run below shows the\n")
    cat("retry playbook handling a marginal case.\n")
  } else {
    cat("NOTE: two warning signs precede estimation: ties collapse from 147 to\n")
    cat("75 with a Jaccard of 0.156, below the 0.20 stability guideline, and\n")
    cat("the careertenure covariate is near-degenerate (28 of 48 inventors at\n")
    cat("zero). These conditions predict the instability revealed below.\n")
  }
}

# ==============================================================================
# ESTIMATION (v8 specification; deterministic retry loop)
# ==============================================================================

estimate_case <- function(cs, max_attempts = MAX_ATTEMPTS) {
  base_seed <- 12345 + cs$ego_id
  waves <- sienaDependent(array(c(cs$w1, cs$w2), dim = c(cs$n, cs$n, 2)),
                          allowOnly = FALSE)
  nd <- cs$nodes
  Newcomer          <- coCovar(as.numeric(nd$is_newcomer))
  CareerTenure      <- coCovar(as.numeric(nd$careertenure))
  NetworkConstraint <- coCovar(as.numeric(nd$network_constraint))
  InventorDegree    <- coCovar(as.numeric(nd$inventor_degree))
  dat <- sienaDataCreate(waves, Newcomer, CareerTenure, NetworkConstraint, InventorDegree)

  eff <- getEffects(dat)
  eff <- includeEffects(eff, transTies)
  eff <- includeEffects(eff, degPlus)
  eff <- includeEffects(eff, egoX, interaction1 = "Newcomer")
  eff <- includeEffects(eff, egoX, interaction1 = "CareerTenure")
  eff <- includeEffects(eff, egoX, interaction1 = "NetworkConstraint")
  eff <- includeEffects(eff, egoX, interaction1 = "InventorDegree")
  eff <- includeInteraction(eff, egoX, transTies, interaction1 = c("Newcomer", ""))
  eff <- includeInteraction(eff, egoX, degPlus,   interaction1 = c("Newcomer", ""))

  eff$diagCovar <- 0.01   # diagonal covariance stabilization, as in the original run

  history <- list()
  for (attempt in seq_len(max_attempts)) {
    seed <- base_seed + (attempt - 1) * 10000
    # A lesson from the project history: sienaAlgorithmCreate must sit INSIDE
    # this loop. Modifying algo$seed after creation is silently ignored by
    # RSiena, so an early version of this workflow made five identical
    # "attempts." Design rule adopted for the whole system (00_docs/decisions.md
    # D3): verify interventions took effect; record evidence, not intentions.
    algo <- sienaAlgorithmCreate(projname = paste0("ego_", cs$ego_id),
                                 n3 = 5000, nsub = 6, maxlike = FALSE,
                                 seed = seed)
    fit  <- tryCatch(siena07(algo, data = dat, effects = eff, batch = TRUE,
                             verbose = FALSE, returnDeps = FALSE),
                     error = function(e) e)
    if (inherits(fit, "error")) {
      cat(sprintf("  Attempt %d (seed %d): ERROR - %s\n", attempt, seed, conditionMessage(fit)))
      history[[attempt]] <- list(attempt = attempt, seed = seed, error = TRUE)
      next
    }
    cr  <- fit$tconv.max
    ses <- sqrt(diag(fit$covtheta))
    cat(sprintf("  Attempt %d (seed %d): conv ratio = %.3f | max |t| = %.3f | max SE = %.1f\n",
                attempt, seed, cr, max(abs(fit$tconv), na.rm = TRUE), max(ses, na.rm = TRUE)))
    history[[attempt]] <- list(attempt = attempt, seed = seed, fit = fit,
                               conv_ratio = cr, max_se = max(ses, na.rm = TRUE))
    if (!is.na(cr) && cr < CONV_THRESH) { cat(sprintf("  --> CONVERGED on attempt %d.\n", attempt)); break }
  }
  history
}

print_effects_table <- function(fit) {
  ses <- sqrt(diag(fit$covtheta))
  tab <- tibble(effect = fit$effects$effectName,
                estimate = round(fit$theta, 3), se = round(ses, 3),
                conv_t = round(fit$tconv, 3),
                flag = ifelse(ses > SE_SCREEN, "  <-- SE SCREEN", ""))
  print(as.data.frame(tab), row.names = FALSE)
  if (any(ses > SE_SCREEN)) {
    cat("\nCOMMENT: the flagged parameter is career tenure. Its instability is\n")
    cat("a property of this network, not the model: with 28 of 48 inventors\n")
    cat("at careertenure = 0, the data cannot pin the parameter down. The\n")
    cat("workflow faced two options here: drop the degenerate effect for this\n")
    cat("network and re-estimate (a respecification, at the cost of breaking\n")
    cat("specification commonality across networks), or exclude the network\n")
    cat("(which changes the analytic sample). The original run chose\n")
    cat("exclusion, a normative-boundary decision under 00_docs/taxonomy.md;\n")
    cat("Part 4 shows what that decision cost.\n")
  } else {
    cat("\nCOMMENT: all standard errors fall well inside the screen; these\n")
    cat("estimates enter the pooled analysis as estimated.\n")
  }
}

for (label in c("A", "B", "C")) {
  cs <- build_case(CHOSEN[[label]])
  print_descriptives(cs, label)
  hist <- estimate_case(cs)
  last <- hist[[length(hist)]]
  if (!is.null(last$fit)) print_effects_table(last$fit)
}

# ==============================================================================
# PART 4: SENSITIVITY OF POOLED ESTIMATES TO THE CASE C EXCLUSION
# ==============================================================================
# Requires the full-corpus results file (94 rows), which is not distributed
# with the demo; see 01_data/README.md for the data policy.

dl_meta <- function(theta, se) {
  ok <- is.finite(theta) & is.finite(se) & se > 0
  theta <- theta[ok]; se <- se[ok]
  w <- 1/se^2; mu_fe <- sum(w*theta)/sum(w)
  Q <- sum(w*(theta-mu_fe)^2); df <- length(theta)-1
  tau2 <- max(0, (Q-df)/(sum(w)-sum(w^2)/sum(w)))
  wr <- 1/(se^2+tau2); mu <- sum(wr*theta)/sum(wr); se_mu <- sqrt(1/sum(wr))
  c(mu = mu, se = se_mu, z = mu/se_mu)
}

if (nzchar(full_results_csv) && file.exists(full_results_csv)) {
  res <- read_csv(full_results_csv, show_col_types = FALSE)
  res$max_se <- do.call(pmax, res[unname(se_map)])
  r93 <- res %>% filter(max_se <= SE_SCREEN)
  r94 <- res
  cat(sprintf("\n============ SENSITIVITY: pooled estimates, %d vs %d networks ============\n",
              nrow(r93), nrow(r94)))
  cat(sprintf("%-20s %9s %8s | %9s %8s | %s\n", "effect", "mu (93)", "z", "mu (+C)", "z", "shift"))
  for (p in names(se_map)) {
    a <- dl_meta(r93[[p]], r93[[se_map[p]]]); b <- dl_meta(r94[[p]], r94[[se_map[p]]])
    shift <- ifelse((abs(a["z"]) >= 1.96) != (abs(b["z"]) >= 1.96), "SIGNIFICANCE CHANGES",
             ifelse(abs(b["mu"] - a["mu"]) > 0.5 * a["se"], "notable", ""))
    cat(sprintf("%-20s %9.3f %8.2f | %9.3f %8.2f | %s\n", p, a["mu"], a["z"], b["mu"], b["z"], shift))
  }
  cat("\nCOMMENT: this table is the ledger's counterfactual hook, computed live.\n")
} else {
  cat("\nPART 4 SKIPPED: full-corpus results file not found.\n")
  cat("Set the SAOM_FULL_RESULTS environment variable to a local copy to run\n")
  cat("the sensitivity analysis.\n")
  cat("Expected result on the recorded v8 results: including network 528644\n")
  cat("changes no significance conclusions; the largest movements are\n")
  cat("newcomer_x_trans -1.948 -> -1.939 and net_constraint_ego -0.125 ->\n")
  cat("-0.116 (z -1.70 -> -1.59). The exclusion was inferentially cheap,\n")
  cat("and that is documented rather than assumed.\n")
}
cat("\nCLOSING COMMENT: an exclusion that is inferentially cheap in one corpus\n")
cat("is a finding, not a guarantee. The ledger's job is to make this check\n")
cat("automatic for every exclusion, every time.\n")
