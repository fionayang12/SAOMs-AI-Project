#!/usr/bin/env Rscript
# Estimate one ego network under the v8 specification; JSON contract v0.2.
# Usage: Rscript engine/estimate_one.R --ego 308631 --data data/demo
#        Rscript engine/estimate_one.R --ego 528644 --data data/demo --drop CareerTenure
#
# --drop removes the egoX effect for the named covariate (CareerTenure or
# NetworkConstraint only). Theory-bearing effects (Newcomer terms,
# InventorDegree) cannot be dropped here: the engine refuses, because that
# decision is normative (docs/taxonomy.md) and no executable path may exist
# for it below the human layer.
suppressPackageStartupMessages({ library(RSiena); library(jsonlite) })

sink(nullfile())  # divert console chatter; the contract permits JSON only on stdout

args <- commandArgs(trailingOnly = TRUE)
gv <- function(flag, default = NULL) {
  i <- which(args == flag); if (length(i)) args[i + 1] else default
}
EGO      <- as.integer(gv("--ego"))
DATA_DIR <- gv("--data", "data/demo")
DROP     <- gv("--drop", NA)
MAX_ATTEMPTS <- 5; CONV_THRESH <- 0.30; SE_SCREEN <- 100
stopifnot(!is.na(EGO))

DROPPABLE <- c("CareerTenure", "NetworkConstraint")
if (!is.na(DROP) && !(DROP %in% DROPPABLE))
  stop(sprintf("--drop %s refused: only peripheral covariates (%s) may be dropped by this path; see docs/taxonomy.md",
               DROP, paste(DROPPABLE, collapse = ", ")))

el <- read.csv(file.path(DATA_DIR, "walkthrough_edgelist.csv"))
nd <- read.csv(file.path(DATA_DIR, "walkthrough_node_attributes.csv"))
el <- el[el$ego_spell_id == EGO, ]; nd <- nd[nd$ego_spell_id == EGO, ]
stopifnot(nrow(nd) > 0)

# --- module: build_network ---------------------------------------------
node_ids <- as.character(nd$inv_code)
yrs <- sort(unique(el$year))
mk <- function(sub) {
  n <- length(node_ids)
  m <- matrix(0, n, n, dimnames = list(node_ids, node_ids))
  if (nrow(sub)) for (k in seq_len(nrow(sub))) {
    i <- as.character(sub$inv1_code[k]); j <- as.character(sub$inv2_code[k])
    if (i %in% node_ids && j %in% node_ids) { m[i, j] <- 1; m[j, i] <- 1 }
  }
  m
}
w1 <- mk(el[el$year == yrs[1], ]); w2 <- mk(el[el$year %in% yrs[-1], ])
jac <- {
  a <- w1[upper.tri(w1)]; b <- w2[upper.tri(w2)]
  u <- sum(a | b); if (u == 0) NA else sum(a & b) / u
}
desc <- list(n_inventors = length(node_ids), n_years = length(yrs),
             n_newcomers = sum(nd$is_newcomer == 1),
             ties_w1 = sum(w1) / 2, ties_w2 = sum(w2) / 2,
             density_w1 = mean(w1[upper.tri(w1)]), jaccard = jac)

# --- module: specify_model ---------------------------------------------
waves <- sienaDependent(array(c(w1, w2), dim = c(length(node_ids), length(node_ids), 2)),
                        allowOnly = FALSE)
Newcomer          <- coCovar(as.numeric(nd$is_newcomer))
CareerTenure      <- coCovar(as.numeric(nd$careertenure))
NetworkConstraint <- coCovar(as.numeric(nd$network_constraint))
InventorDegree    <- coCovar(as.numeric(nd$inventor_degree))
dat <- sienaDataCreate(waves, Newcomer, CareerTenure, NetworkConstraint, InventorDegree)
eff <- getEffects(dat)
eff <- includeEffects(eff, transTies)
eff <- includeEffects(eff, degPlus)
covariates <- c("Newcomer", "CareerTenure", "NetworkConstraint", "InventorDegree")
if (!is.na(DROP)) covariates <- setdiff(covariates, DROP)
for (cv in covariates)
  eff <- includeEffects(eff, egoX, interaction1 = cv)
eff <- includeInteraction(eff, egoX, transTies, interaction1 = c("Newcomer", ""))
eff <- includeInteraction(eff, egoX, degPlus,   interaction1 = c("Newcomer", ""))
eff$diagCovar <- 0.01

# --- module: estimate (retry loop; playbook rules) ----------------------
base_seed <- 12345 + EGO
attempts <- list(); final_fit <- NULL
for (attempt in seq_len(MAX_ATTEMPTS)) {
  seed <- base_seed + (attempt - 1) * 10000
  # sienaAlgorithmCreate must sit INSIDE the loop (docs/decisions.md D3).
  algo <- sienaAlgorithmCreate(projname = paste0("ego_", EGO),
                               n3 = 5000, nsub = 6, maxlike = FALSE, seed = seed)
  fit <- tryCatch(siena07(algo, data = dat, effects = eff, batch = TRUE,
                          verbose = FALSE, returnDeps = FALSE),
                  error = function(e) e)
  if (inherits(fit, "error")) {
    attempts[[attempt]] <- list(attempt = attempt, seed = seed, error = conditionMessage(fit))
    next
  }
  ses <- sqrt(diag(fit$covtheta))
  rec <- list(attempt = attempt, seed = seed,
              conv_ratio = as.numeric(fit$tconv.max),
              max_abs_t = max(abs(fit$tconv), na.rm = TRUE),
              max_se = max(ses, na.rm = TRUE),
              converged = isTRUE(fit$tconv.max < CONV_THRESH))
  attempts[[attempt]] <- rec
  if (rec$converged) { final_fit <- fit; break }
  final_fit <- fit
}

# --- module: diagnostics + JSON out -------------------------------------
spec <- list(version = "v8",
             dropped = if (is.na(DROP)) list() else list(DROP))
if (is.null(final_fit)) {
  out <- list(ego = EGO, descriptives = desc, attempts = attempts,
              spec = spec, final = list(status = "error"))
} else {
  ses <- sqrt(diag(final_fit$covtheta))
  status <- if (isTRUE(final_fit$tconv.max < CONV_THRESH)) "converged" else "not_converged"
  out <- list(
    ego = EGO, descriptives = desc, attempts = attempts, spec = spec,
    final = list(
      status = status,
      estimates = lapply(seq_along(final_fit$theta), function(i) list(
        effect = final_fit$effects$effectName[i],
        theta = unname(final_fit$theta[i]), se = unname(ses[i]),
        conv_t = unname(final_fit$tconv[i]))),
      flags = list(se_screen_tripped = any(ses > SE_SCREEN),
                   jaccard_below_020 = isTRUE(jac < 0.20))
    ),
    software = list(r = paste(R.version$major, R.version$minor, sep = "."),
                    rsiena = as.character(packageVersion("RSiena")))
  )
}
sink()
cat(toJSON(out, auto_unbox = TRUE, digits = 6, na = "null"))
