# ==============================================================================
# A guided tour of three exemplar networks
# ==============================================================================
# CHOSEN EXEMPLARS:
#
#   CASE A = 308631  (stratum A, 58 inventors, 13 newcomers)
#     Clean baseline: conv ratio 0.051, Jaccard 0.323, max SE 1.68.
#     Every diagnostic green. Calibrates what "healthy" looks like.
#
#   CASE B = 109049  (stratum A, 64 inventors, 8 newcomers)
#     Hard-won convergence: conv ratio 0.295, a hair under the 0.30 threshold,
#     with Jaccard 0.095, WELL below the 0.20 stability guideline. Retained.
#     NOTE: the results file records no attempt counts, so "rescued on attempt
#     k" cannot be recovered from the CSV; the live rerun in PART 3 will show
#     the retry loop in action. Discussion point built into this case: the
#     Jaccard threshold operated as a FLAG, not an exclusion rule. Was
#     retaining this network the right call? Under the taxonomy, who decides,
#     and where would the ledger record it?
#
#   CASE C = 528644  (stratum B, 48 inventors, 6 newcomers)
#     THE difficult network: converged nominally (ratio 0.219) but
#     se_career_tenure = 133.2, tripping the SE > 100 screen. Excluded from
#     the analytic sample (the 94th network; 93 retained).
#     Diagnosis (precomputed): careertenure is near-degenerate here: 28 of 48
#     inventors have careertenure = 0 (median 0, mean 1.69). The data cannot
#     pin down the parameter. And the descriptives predicted trouble: ties
#     COLLAPSE from 147 (wave 1) to 75 (wave 2), Jaccard 0.156, massive
#     dissolution straining the gradual-change assumption.
#     Options at the decision point: (i) drop career_tenure_ego for this
#     network and re-estimate (respecification: institutional proposal +
#     human sign-off, but note it breaks specification commonality across
#     networks); (ii) exclude (normative: changes the analytic sample).
#     The v8 run chose exclusion. PART 4 shows what that decision cost.
#
# VALIDATION ALREADY PERFORMED (so you can trust the code Monday):
#   - The wave-construction logic below EXACTLY reproduces the recorded
#     ties_w1, ties_w2, and Jaccard for all three networks.
#   - The DL meta-analysis function reproduces the published Panel A values
#     (e.g., newcomer_x_trans mu = -1.95, z = -5.12) from the 93 networks.
#
# PRECOMPUTED PART 4 RESULT (rehearsal reference):
#   Including 528644 changes NO significance conclusions. Largest movements:
#   newcomer_x_trans -1.948 -> -1.939; net_constraint_ego -0.125 -> -0.116
#   (z -1.70 -> -1.59). The exclusion was inferentially cheap, and now that
#   is documented rather than assumed. Meeting close: cheap THIS time is a
#   finding, not a guarantee; the ledger makes it checkable every time.
# ==============================================================================

library(RSiena)
library(tidyverse)

# --- CONFIG -------------------------------------------------------------------
data_dir <- "/Users/mdh189/Dropbox/Fiona Project/SAOM Analysis"  # adjust per machine
wt_dir   <- file.path(data_dir, "walkthrough_data")   # from walkthrough_data.zip

# Seed formula recovered from newcomer_saom_meta_v8.R: per-network,
# base_seed = 12345 + ego_spell_id, attempt offset +10000. With the same
# RSiena version this reproduces the recorded run exactly.
MAX_ATTEMPTS <- 5
CONV_THRESH  <- 0.30
SE_SCREEN    <- 100

CHOSEN <- list(A = 308631, B = 109049, C = 528644)

el_all    <- read_csv(file.path(wt_dir, "walkthrough_edgelist.csv"), show_col_types = FALSE)
nodes_all <- read_csv(file.path(wt_dir, "walkthrough_node_attributes.csv"), show_col_types = FALSE)
res_rows  <- read_csv(file.path(wt_dir, "walkthrough_v8_results_rows.csv"), show_col_types = FALSE)

# Estimate/SE column pairs in the results file (names differ slightly; mapped
# explicitly rather than auto-detected):
se_map <- c(density = "se_density", transitivity = "se_transitivity",
            deg_act_pop = "se_deg_act_pop", newcomer_ego = "se_newcomer_ego",
            career_tenure_ego = "se_career_tenure",
            net_constraint_ego = "se_net_constraint",
            inv_degree_ego = "se_inv_degree",
            newcomer_x_trans = "se_newcomer_x_trans",
            newcomer_x_degplus = "se_newcomer_x_degplus")

# ==============================================================================
# NETWORK CONSTRUCTION (validated: reproduces recorded ties and Jaccard)
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
  cat("PROMPT: before estimating, what do these descriptives predict about\n")
  cat("estimation difficulty, and why?\n")
}

# ==============================================================================
# ESTIMATION (v8 specification, retry loop with the seed lesson in place)
# ==============================================================================

estimate_case <- function(cs, max_attempts = MAX_ATTEMPTS) {
  base_seed <- 12345 + cs$ego_id   # v8 formula
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

  eff$diagCovar <- 0.01   # diagonal covariance stabilization, as in v8

  history <- list()
  for (attempt in seq_len(max_attempts)) {
    seed <- base_seed + (attempt - 1) * 10000
    # LESSON (tell it at Case B): sienaAlgorithmCreate must sit INSIDE this
    # loop. Modifying algo$seed after creation is silently ignored, so early
    # runs made five identical "attempts." Agent design requirement: verify
    # interventions took effect; ledger records evidence, not intentions.
    algo <- sienaAlgorithmCreate(projname = paste0("ego_", cs$ego_id),
                                 n3 = 5000, nsub = 6, maxlike = FALSE,
                                 seed = seed)   # identical settings to v8
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
  cat("\nPROMPTS:\n")
  cat("  1. Which parameter is unstable, and what about THIS network makes it so?\n")
  cat("  2. Options: drop the degenerate effect here and re-estimate (institutional:\n")
  cat("     proposal + sign-off, but breaks specification commonality), or exclude\n")
  cat("     (normative: changes the analytic sample). v8 chose exclusion.\n")
  cat("  3. Note line: decision point | information available | action | rationale |\n")
  cat("     could an agent do this, and under what rule?\n")
}

for (label in c("A", "B", "C")) {
  cs <- build_case(CHOSEN[[label]])
  print_descriptives(cs, label)
  hist <- estimate_case(cs)
  last <- hist[[length(hist)]]
  if (!is.null(last$fit)) print_effects_table(last$fit)
}

# ==============================================================================
# PART 4: SENSITIVITY. Requires the FULL results file (all 94 rows).
# ==============================================================================
res <- read_csv(file.path(data_dir, "SAOM_newcomer_results_v8.csv"), show_col_types = FALSE)
res$max_se <- do.call(pmax, res[unname(se_map)])

dl_meta <- function(theta, se) {
  ok <- is.finite(theta) & is.finite(se) & se > 0
  theta <- theta[ok]; se <- se[ok]
  w <- 1/se^2; mu_fe <- sum(w*theta)/sum(w)
  Q <- sum(w*(theta-mu_fe)^2); df <- length(theta)-1
  tau2 <- max(0, (Q-df)/(sum(w)-sum(w^2)/sum(w)))
  wr <- 1/(se^2+tau2); mu <- sum(wr*theta)/sum(wr); se_mu <- sqrt(1/sum(wr))
  c(mu = mu, se = se_mu, z = mu/se_mu)
}

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
cat("\nCLOSE: this table is the ledger's counterfactual hook, computed live.\n")
cat("Precomputed answer: no significance changes; the exclusion of 528644 was\n")
cat("inferentially cheap. Cheap THIS time is a finding, not a guarantee: the\n")
cat("ledger's job is to make it checkable every time, for every exclusion.\n")
