# ==============================================================================
# SAOM META-ANALYSIS: NEWCOMER INVENTOR NETWORKS & BREAKTHROUGH INNOVATION
# Version 8: Newcomer interaction effects
# ==============================================================================
# Changes from v7:
#   ADDED:   Newcomer ego × transitive ties interaction
#            Tests whether newcomers close triads at a different rate than
#            incumbents. Positive = newcomers embed in existing clusters;
#            negative = newcomers bridge across clusters.
#   ADDED:   Newcomer ego × degree act+pop interaction
#            Tests whether newcomers differentially attach to high-degree
#            inventors (preferential attachment differential). Positive =
#            newcomers selectively connect to hubs.
#
# Retained from v7:
#   All 7 main effects: density, transTies, degPlus, Newcomer ego,
#   CareerTenure ego, NetworkConstraint ego, InventorDegree ego
#   Bug fix: sienaAlgorithmCreate inside retry loop with unique seeds
#   Handles 1-2 year networks
#
# Wave design (unchanged):
#   Wave 1 = first year (arrival snapshot)
#   Wave 2 = union of remaining years (post-integration network)
#
# Effect specification (9 effects):
#   Structural: density (outdegree), transitive ties, degree act+pop
#   Covariate ego effects: Newcomer, CareerTenure, NetworkConstraint,
#                          InventorDegree
#   Interactions: Newcomer ego × transitive ties
#                 Newcomer ego × degree act+pop
#
# Data inputs (pre-processed from Python):
#   ego_node_attributes.csv - node-level covariates per ego network
#   ego_edgelist_clean.csv  - edgelist with ego_spell_id, year, inv1, inv2, stratum
# ==============================================================================

library(RSiena)
library(tidyverse)
library(readr)

# --- CONFIGURE PATHS ---------------------------------------------------------
# UPDATE THIS to your local path where the CSV files are stored
data_dir   <- "/Users/michaelhoward/Dropbox/Fiona Project/SAOM Analysis"
output_csv <- file.path(data_dir, "SAOM_newcomer_results_v8.csv")

# --- LOAD DATA ---------------------------------------------------------------
cat("Loading data...\n")
el_all    <- read_csv(file.path(data_dir, "ego_edgelist_clean.csv"), show_col_types = FALSE)
nodes_all <- read_csv(file.path(data_dir, "ego_node_attributes.csv"), show_col_types = FALSE)

ego_ids <- sort(unique(nodes_all$ego_spell_id))
cat(sprintf("Total ego networks to process: %d\n", length(ego_ids)))
cat(sprintf("Rows in edgelist: %d\n", nrow(el_all)))
cat(sprintf("Rows in node attributes: %d\n", nrow(nodes_all)))

# --- HELPER: Build undirected adjacency matrix from edgelist -----------------
make_undirected <- function(el, node_ids) {
  n <- length(node_ids)
  mat <- matrix(0, n, n, dimnames = list(node_ids, node_ids))
  if (nrow(el) == 0) return(mat)
  for (i in seq_len(nrow(el))) {
    f <- as.character(el$inv1_code[i])
    t <- as.character(el$inv2_code[i])
    if (f %in% node_ids && t %in% node_ids && f != t) {
      mat[f, t] <- 1
      mat[t, f] <- 1
    }
  }
  diag(mat) <- 0
  mat
}

# --- MAIN LOOP ---------------------------------------------------------------
results <- data.frame()
cat("Starting SAOM estimation loop (v8: +Newcomer×transTies, +Newcomer×degPlus)\n")
cat("==============================================================\n")

for (ego in ego_ids) {
  
  # --- Get data for this ego network ----------------------------------------
  ego_nodes <- nodes_all %>% filter(ego_spell_id == ego)
  ego_edges <- el_all    %>% filter(ego_spell_id == ego)
  
  node_ids <- as.character(sort(ego_nodes$inv_code))
  n_nodes  <- length(node_ids)
  stratum  <- ego_nodes$stratum[1]
  years    <- sort(unique(ego_edges$year))
  n_years  <- length(years)
  
  cat(sprintf("\n=== Ego %d | n=%d | stratum=%s | years=%s ===\n",
              ego, n_nodes, stratum, paste(years, collapse=",")))
  
  # --- Skip very small networks ---------------------------------------------
  if (n_nodes < 5) {
    cat("  Too few nodes (< 5) -> skipped\n")
    next
  }
  
  # --- Skip networks with only 1 year (cannot form 2-wave SAOM) -------------
  if (n_years < 2) {
    cat("  Only 1 year of data -> skipped (need >=2 for 2-wave SAOM)\n")
    next
  }
  
  # --- Build adjacency matrices: 2-wave design ------------------------------
  # Wave 1 = first year (arrival snapshot)
  # Wave 2 = union of all remaining years (post-integration)
  adj_wave1 <- make_undirected(ego_edges %>% filter(year == years[1]), node_ids)
  
  if (n_years == 2) {
    # 2-year networks: wave 2 = year 2
    adj_wave2 <- make_undirected(ego_edges %>% filter(year == years[2]), node_ids)
  } else {
    # 3+ year networks: wave 2 = union of years 2 and 3
    adj_y2 <- make_undirected(ego_edges %>% filter(year == years[2]), node_ids)
    adj_y3 <- make_undirected(ego_edges %>% filter(year == years[3]), node_ids)
    adj_wave2 <- pmin(adj_y2 + adj_y3, 1)  # union of years 2 and 3
  }
  
  # --- Check for sufficient change between waves ----------------------------
  changes <- sum(adj_wave1 != adj_wave2)
  if (changes == 0) {
    cat("  No tie changes between waves -> skipped\n")
    next
  }
  
  # --- Report Jaccard for diagnostics ---------------------------------------
  ties_w1 <- sum(adj_wave1[upper.tri(adj_wave1)])
  ties_w2 <- sum(adj_wave2[upper.tri(adj_wave2)])
  both    <- sum((adj_wave1 * adj_wave2)[upper.tri(adj_wave1)])
  either  <- sum(pmin(adj_wave1 + adj_wave2, 1)[upper.tri(adj_wave1)])
  jaccard <- if (either > 0) both / either else 0
  cat(sprintf("  Ties: w1=%d, w2=%d | Jaccard=%.3f | n_years=%d\n",
              ties_w1, ties_w2, jaccard, n_years))
  
  # --- Create RSiena dependent variable (2-wave undirected network) ----------
  net_array <- array(c(adj_wave1, adj_wave2), dim = c(n_nodes, n_nodes, 2))
  netdep <- sienaDependent(net_array, type = "oneMode", allowOnly = FALSE)
  
  # --- Create constant covariates from node attributes -----------------------
  # Order must match node_ids
  ego_nodes <- ego_nodes %>% arrange(match(as.character(inv_code), node_ids))
  
  Newcomer          <- coCovar(as.numeric(ego_nodes$is_newcomer))
  CareerTenure      <- coCovar(as.numeric(ego_nodes$careertenure))
  NetworkConstraint <- coCovar(as.numeric(ego_nodes$network_constraint))
  InventorDegree    <- coCovar(as.numeric(ego_nodes$inventor_degree))
  
  # --- Check for covariate variation ----------------------------------------
  if (length(unique(ego_nodes$is_newcomer)) <= 1) {
    cat("  No newcomer variation -> skipped\n")
    next
  }
  
  # --- Create RSiena data object --------------------------------------------
  data <- sienaDataCreate(netdep, Newcomer, CareerTenure, NetworkConstraint,
                          InventorDegree)
  
  # --- Specify effects -------------------------------------------------------
  eff <- getEffects(data)
  
  # Structural: transitive ties (density/outdegree is included by default)
  eff <- includeEffects(eff, transTies, include = TRUE)
  
  # Degree activity+popularity (preferential attachment)
  eff <- includeEffects(eff, degPlus, include = TRUE)
  
  # Covariate ego effects (main effects — must be included before interactions)
  eff <- includeEffects(eff, egoX, interaction1 = "Newcomer")
  eff <- includeEffects(eff, egoX, interaction1 = "CareerTenure")
  eff <- includeEffects(eff, egoX, interaction1 = "NetworkConstraint")
  eff <- includeEffects(eff, egoX, interaction1 = "InventorDegree")
  
  # --- NEW in v8: Interaction effects ----------------------------------------
  # Newcomer ego × transitive ties:
  #   Do newcomers close triads at different rates than incumbents?
  eff <- includeInteraction(eff, egoX, transTies,
                            interaction1 = c("Newcomer", ""))
  
  # Newcomer ego × degree act+pop (preferential attachment):
  #   Do newcomers differentially attach to high-degree inventors?
  eff <- includeInteraction(eff, egoX, degPlus,
                            interaction1 = c("Newcomer", ""))
  
  # Diagonal covariance stabilization
  eff$diagCovar <- 0.01
  
  # --- Estimate with up to 5 attempts ----------------------------------------
  ans <- NULL
  base_seed <- 12345 + ego
  for (attempt in 1:5) {
    algo <- sienaAlgorithmCreate(
      projname = paste0("ego_", ego),
      n3       = 5000,
      nsub     = 6,
      maxlike  = FALSE,
      seed     = base_seed + (attempt - 1) * 10000
    )
    ans <- tryCatch(
      siena07(algo, data = data, effects = eff,
              batch = TRUE, verbose = FALSE,
              returnDeps = FALSE),
      error = function(e) {
        cat(sprintf("  Attempt %d error: %s\n", attempt, e$message))
        NULL
      }
    )
    if (!is.null(ans) && !is.na(ans$tconv.max) && ans$tconv.max < 0.30) break
  }
  
  # --- Check convergence -----------------------------------------------------
  if (is.null(ans) || is.na(ans$tconv.max) || ans$tconv.max >= 0.30) {
    cat("  Did not converge -> skipped\n")
    next
  }
  
  # --- Check for singular covariance matrix (before extracting SEs) ----------
  if (!is.matrix(ans$covtheta)) {
    cat("  Singular covariance matrix -> skipped\n")
    next
  }
  
  cat(sprintf("  CONVERGED! tconv.max = %.3f\n", ans$tconv.max))
  
  # --- Extract estimates and SEs --------------------------------------------
  theta  <- ans$theta
  enames <- ans$effects$effectName
  se_vec <- sqrt(diag(ans$covtheta))
  
  # Print effect names on first convergence for debugging
  if (nrow(results) == 0) {
    cat("  Effect names from RSiena:\n")
    for (i in seq_along(enames)) {
      cat(sprintf("    [%d] %s\n", i, enames[i]))
    }
  }
  
  # Helper: safely extract a scalar by effect name pattern
  # For interactions, RSiena may use various naming conventions.
  # We try exact match first, then grep with fixed = TRUE.
  get_est <- function(pattern) {
    idx <- which(enames == pattern)
    if (length(idx) == 1) return(as.numeric(theta[idx]))
    idx <- grep(pattern, enames, fixed = TRUE)
    if (length(idx) == 1) return(as.numeric(theta[idx]))
    if (length(idx) > 1) {
      cat(sprintf("  WARNING: multiple matches for '%s', using first\n", pattern))
      return(as.numeric(theta[idx[1]]))
    }
    cat(sprintf("  WARNING: no match for '%s'\n", pattern))
    return(NA_real_)
  }
  get_se <- function(pattern) {
    idx <- which(enames == pattern)
    if (length(idx) == 1) return(as.numeric(se_vec[idx]))
    idx <- grep(pattern, enames, fixed = TRUE)
    if (length(idx) == 1) return(as.numeric(se_vec[idx]))
    if (length(idx) > 1) return(as.numeric(se_vec[idx[1]]))
    return(NA_real_)
  }
  
  # --- Build output row ------------------------------------------------------
  # NOTE: Interaction effect names are printed on first convergence.
  #   Expected names (verify against console output):
  #     "Newcomer ego x transitive ties"
  #     "Newcomer ego x degree act+pop"
  #   If RSiena uses different naming, update the patterns below.
  row_out <- data.frame(
    ego_spell_id       = ego,
    stratum            = stratum,
    n_inventors        = n_nodes,
    n_newcomers        = sum(ego_nodes$is_newcomer),
    n_years            = n_years,
    convergence        = ans$tconv.max,
    jaccard            = jaccard,
    ties_w1            = ties_w1,
    ties_w2            = ties_w2,
    # --- Main effect estimates ---
    density            = get_est("degree (density)"),
    transitivity       = get_est("transitive ties"),
    deg_act_pop        = get_est("degree act+pop"),
    newcomer_ego       = get_est("Newcomer ego"),
    career_tenure_ego  = get_est("CareerTenure ego"),
    net_constraint_ego = get_est("NetworkConstraint ego"),
    inv_degree_ego     = get_est("InventorDegree ego"),
    # --- Interaction estimates ---
    newcomer_x_trans   = get_est("Newcomer ego x transitive ties"),
    newcomer_x_degplus = get_est("Newcomer ego x degree act+pop"),
    # --- Main effect SEs ---
    se_density         = get_se("degree (density)"),
    se_transitivity    = get_se("transitive ties"),
    se_deg_act_pop     = get_se("degree act+pop"),
    se_newcomer_ego    = get_se("Newcomer ego"),
    se_career_tenure   = get_se("CareerTenure ego"),
    se_net_constraint  = get_se("NetworkConstraint ego"),
    se_inv_degree      = get_se("InventorDegree ego"),
    # --- Interaction SEs ---
    se_newcomer_x_trans   = get_se("Newcomer ego x transitive ties"),
    se_newcomer_x_degplus = get_se("Newcomer ego x degree act+pop"),
    stringsAsFactors   = FALSE
  )
  
  results <- rbind(results, row_out)
  write_csv(results, output_csv)
  cat(sprintf("  Saved (total converged = %d)\n", nrow(results)))
}

# --- SUMMARY -----------------------------------------------------------------
cat("\n==============================================================\n")
cat("FINISHED!\n")
cat(sprintf("Total converged models: %d of %d attempted\n", nrow(results), length(ego_ids)))
cat(sprintf("Results saved to: %s\n", output_csv))

if (nrow(results) > 0) {
  cat("\nConverged models by stratum:\n")
  print(table(results$stratum))
  
  cat("\nConverged models by n_years:\n")
  print(table(results$n_years))
  
  cat("\nSummary of key estimates:\n")
  cat(sprintf("  Density:                  mean=%.3f, sd=%.3f\n",
              mean(results$density, na.rm=TRUE),
              sd(results$density, na.rm=TRUE)))
  cat(sprintf("  Transitivity:             mean=%.3f, sd=%.3f\n",
              mean(results$transitivity, na.rm=TRUE),
              sd(results$transitivity, na.rm=TRUE)))
  cat(sprintf("  Degree act+pop:           mean=%.3f, sd=%.3f\n",
              mean(results$deg_act_pop, na.rm=TRUE),
              sd(results$deg_act_pop, na.rm=TRUE)))
  cat(sprintf("  Newcomer ego:             mean=%.3f, sd=%.3f\n",
              mean(results$newcomer_ego, na.rm=TRUE),
              sd(results$newcomer_ego, na.rm=TRUE)))
  cat(sprintf("  Career tenure ego:        mean=%.3f, sd=%.3f\n",
              mean(results$career_tenure_ego, na.rm=TRUE),
              sd(results$career_tenure_ego, na.rm=TRUE)))
  cat(sprintf("  Net constraint ego:       mean=%.3f, sd=%.3f\n",
              mean(results$net_constraint_ego, na.rm=TRUE),
              sd(results$net_constraint_ego, na.rm=TRUE)))
  cat(sprintf("  Inventor degree ego:      mean=%.3f, sd=%.3f\n",
              mean(results$inv_degree_ego, na.rm=TRUE),
              sd(results$inv_degree_ego, na.rm=TRUE)))
  cat(sprintf("  Newcomer x TransTies:     mean=%.3f, sd=%.3f\n",
              mean(results$newcomer_x_trans, na.rm=TRUE),
              sd(results$newcomer_x_trans, na.rm=TRUE)))
  cat(sprintf("  Newcomer x DegPlus:       mean=%.3f, sd=%.3f\n",
              mean(results$newcomer_x_degplus, na.rm=TRUE),
              sd(results$newcomer_x_degplus, na.rm=TRUE)))
  cat(sprintf("  Avg Jaccard:              mean=%.3f\n",
              mean(results$jaccard, na.rm=TRUE)))
}
