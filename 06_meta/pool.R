#!/usr/bin/env Rscript
# DL random-effects pooling + exclusion-rule sensitivity.
# Usage: Rscript 06_meta/pool.R --results /path/to/SAOM_newcomer_results_v8.csv
args <- commandArgs(trailingOnly = TRUE)
gv <- function(flag, default = NULL) { i <- which(args == flag); if (length(i)) args[i+1] else default }
RESULTS <- gv("--results"); SE_SCREEN <- as.numeric(gv("--se-screen", "100"))
stopifnot(!is.null(RESULTS))
res <- read.csv(RESULTS)

se_map <- c(density = "se_density", transitivity = "se_transitivity",
            deg_act_pop = "se_deg_act_pop", newcomer_ego = "se_newcomer_ego",
            career_tenure_ego = "se_career_tenure",
            net_constraint_ego = "se_net_constraint",
            inv_degree_ego = "se_inv_degree",
            newcomer_x_trans = "se_newcomer_x_trans",
            newcomer_x_degplus = "se_newcomer_x_degplus")

dl_meta <- function(theta, se) {
  ok <- is.finite(theta) & is.finite(se) & se > 0
  theta <- theta[ok]; se <- se[ok]
  w <- 1/se^2; mu_fe <- sum(w*theta)/sum(w)
  Q <- sum(w*(theta-mu_fe)^2); df <- length(theta)-1
  tau2 <- max(0, (Q-df)/(sum(w)-sum(w^2)/sum(w)))
  wr <- 1/(se^2+tau2)
  c(mu = sum(wr*theta)/sum(wr), se = sqrt(1/sum(wr)), k = length(theta))
}

res$max_se <- do.call(pmax, res[unname(se_map)])
keep <- res$max_se <= SE_SCREEN
cat(sprintf("Pooling %d networks (of %d; SE screen %g)\n\n", sum(keep), nrow(res), SE_SCREEN))
cat(sprintf("%-20s %9s %8s %6s\n", "effect", "mu", "z", "k"))
for (p in names(se_map)) {
  m <- dl_meta(res[keep, p], res[keep, se_map[p]])
  cat(sprintf("%-20s %9.3f %8.2f %6d\n", p, m["mu"], m["mu"]/m["se"], m["k"]))
}
