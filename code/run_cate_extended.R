# ==============================================================================
# MICS DoubleML - Extended CATE Analysis (Influence Function Approach)
# ==============================================================================
# Uses influence functions from already-fitted DoubleML models to compute
# Conditional Average Treatment Effects WITHOUT any re-estimation.
#
# Key insight: For any fitted DoubleMLIRM model:
#   CATE(g) = theta + mean(phi_i | i in subgroup g)
#   SE(g)   = sd(phi_i | i in subgroup g) / sqrt(N_g)
#
# where phi_i are the influence functions (mean over cross-fitting reps).
# This is equivalent to the "CATE by subset" approach (Chernozhukov et al.)
# and avoids re-running cross-fitting for every subgroup.
# ==============================================================================

library(here)
library(data.table)

source(here::here("code", "config.R"))
source(here::here("code", "data.R"))

# ==============================================================================
# FUNCTION: Compute CATEs from influence functions of a fitted DoubleML model
# ==============================================================================

compute_cates_from_model <- function(checkpoint_file, dt_full, phi_var_name = NULL) {
  # Load the fitted model checkpoint
  cp <- readRDS(checkpoint_file)
  dml <- cp$model
  theta <- cp$coef
  
  # Extract influence functions from the fitted model
  pb <- dml$psi_b[,,1]   # (N, n_rep) — score components at theta=0
  phi <- rowMeans(pb) - theta  # influence functions, mean(phi) = 0 by construction
  
  # The model$data contains the data used for fitting (complete cases)
  dat <- dml$data$data
  
  # Return influence functions + the fitting data
  list(
    theta = theta,
    phi = phi,
    dat = dat,
    outcome = cp$outcome,
    treatment = cp$treatment,
    learner = cp$learner,
    n = cp$n
  )
}

# ==============================================================================
# FUNCTION: CATE for a single subgroup variable
# ==============================================================================

cate_by_subgroup <- function(if_obj, subgroup_col, subgroup_labels = NULL) {
  # Compute CATE for each level of a subgroup variable
  # subgroup_col: column name in the model data (e.g., "urban_bin")
  # subgroup_labels: named vector mapping values to labels
  
  phi <- if_obj$phi
  theta <- if_obj$theta
  dat <- if_obj$dat
  
  levels <- unique(dat[[subgroup_col]])
  levels <- levels[!is.na(levels)]
  levels <- sort(levels)
  
  results <- data.table()
  
  for (val in levels) {
    idx <- which(dat[[subgroup_col]] == val)
    
    if (length(idx) < 10) next
    
    cate <- theta + mean(phi[idx])
    se <- sd(phi[idx]) / sqrt(length(idx))
    ci_lo <- cate - 1.96 * se
    ci_hi <- cate + 1.96 * se
    t_val <- cate / se
    p_val <- 2 * pnorm(-abs(t_val))
    
    label <- if (!is.null(subgroup_labels) && as.character(val) %in% names(subgroup_labels)) {
      subgroup_labels[as.character(val)]
    } else {
      as.character(val)
    }
    
    results <- rbind(results, data.table(
      outcome = if_obj$outcome,
      treatment = if_obj$treatment,
      learner = if_obj$learner,
      subgroup = subgroup_col,
      subgroup_value = val,
      subgroup_label = label,
      cate = cate,
      se = se,
      ci_lower = ci_lo,
      ci_upper = ci_hi,
      t_stat = t_val,
      p_value = p_val,
      significant = ifelse(p_val < 0.05, "***", ""),
      N = length(idx)
    ))
  }
  
  return(results)
}

# ==============================================================================
# FUNCTION: Cross-subgroup significance test
# ==============================================================================

test_heterogeneity <- function(results, group1_val, group2_val) {
  # Wald test for difference between two subgroups
  r1 <- results[subgroup_value == as.character(group1_val)]
  r2 <- results[subgroup_value == as.character(group2_val)]
  
  if (nrow(r1) == 0 || nrow(r2) == 0) return(NULL)
  
  diff <- r1$cate - r2$cate
  se_diff <- sqrt(r1$se^2 + r2$se^2)
  z <- diff / se_diff
  p <- 2 * pnorm(-abs(z))
  
  list(
    group1 = r1$subgroup_label,
    group2 = r2$subgroup_label,
    diff = diff,
    se_diff = se_diff,
    z_stat = z,
    p_value = p
  )
}

# ==============================================================================
# MAIN: Load data and compute CATEs for all models
# ==============================================================================

cat("========================================\n")
cat("CATE ANALYSIS — Influence Function Approach\n")
cat("(No models re-estimated)\n")
cat("========================================\n\n")

# ==============================================================================
# 1. LOAD FITTED MODELS (checkpoints)
# ==============================================================================

cat("Loading fitted models from checkpoints...\n")

# Boil → Diarrhea (ATE = -0.0447, N = 25,202)
cat("  Boil → Diarrhea: ")
if_diarr_boil <- compute_cates_from_model(
  file.path(CHECKPOINT_DIR, "diarrhea_treat_boil_stacked.rds")
)
cat(sprintf("theta = %.4f, N = %d\n", if_diarr_boil$theta, if_diarr_boil$n))

# Boil → VeryHighRiskHome (ATE = -0.1058, N = 59,620)
cat("  Boil → VeryHighRiskHome: ")
if_ecoli_boil <- compute_cates_from_model(
  file.path(CHECKPOINT_DIR, "very_high_risk_home_treat_boil_stacked.rds")
)
cat(sprintf("theta = %.4f, N = %d\n", if_ecoli_boil$theta, if_ecoli_boil$n))

# Boil → SomeRiskHome (ATE = -0.044, N = 59,620)
cat("  Boil → SomeRiskHome: ")
if_some_boil <- compute_cates_from_model(
  file.path(CHECKPOINT_DIR, "some_risk_home_treat_boil_stacked.rds")
)
cat(sprintf("theta = %.4f, N = %d\n", if_some_boil$theta, if_some_boil$n))

# ==============================================================================
# 2. CATE BY URBAN/RURAL
# ==============================================================================

cat("\n\n")
cat("############################################################\n")
cat("# CATE: URBAN vs RURAL\n")
cat("############################################################\n")

urban_labels <- c("0" = "Rural", "1" = "Urban")

for (if_obj in list(if_diarr_boil, if_ecoli_boil, if_some_boil)) {
  cat("\n--- Outcome:", if_obj$outcome, "| Treatment:", if_obj$treatment, "---\n")
  
  results <- cate_by_subgroup(if_obj, "urban_bin", urban_labels)
  
  cat(sprintf("  Overall ATE: %.4f\n", if_obj$theta))
  for (i in 1:nrow(results)) {
    cat(sprintf("  %s: %.4f (%.4f) [%.4f, %.4f] %s  N=%d\n",
                results$subgroup_label[i], results$cate[i], results$se[i],
                results$ci_lower[i], results$ci_upper[i],
                results$significant[i], results$N[i]))
  }
  
  # Test Urban vs Rural
  ht <- test_heterogeneity(results, 0, 1)
  if (!is.null(ht)) {
    cat(sprintf("  Diff (%s - %s): %.4f (%.4f), p=%.4f\n",
                ht$group1, ht$group2, ht$diff, ht$se_diff, ht$p_value))
  }
}

# ==============================================================================
# 3. CATE BY WEALTH QUINTILE
# ==============================================================================

cat("\n\n")
cat("############################################################\n")
cat("# CATE: WEALTH QUINTILES\n")
cat("############################################################\n")

wealth_labels <- c("1" = "Q1 (Poorest)", "2" = "Q2", "3" = "Q3", "4" = "Q4", "5" = "Q5 (Richest)")

all_cates <- data.table()

for (if_obj in list(if_diarr_boil, if_ecoli_boil, if_some_boil)) {
  cat("\n--- Outcome:", if_obj$outcome, "| Treatment:", if_obj$treatment, "---\n")
  
  # Wealth: 5 separate dummy columns (wealth_q1 ... wealth_q5)
  # Need to map to a single variable
  dat <- if_obj$dat
  phi <- if_obj$phi
  theta <- if_obj$theta
  
  # Determine wealth quintile for each obs
  wealth_quintile <- rep(NA, nrow(dat))
  for (q in 1:5) {
    wealth_quintile[dat[[paste0("wealth_q", q)]] == 1] <- q
  }
  
  results <- data.table()
  
  for (q in 1:5) {
    idx <- which(wealth_quintile == q)
    
    if (length(idx) < 10) next
    
    cate <- theta + mean(phi[idx])
    se <- sd(phi[idx]) / sqrt(length(idx))
    ci_lo <- cate - 1.96 * se
    ci_hi <- cate + 1.96 * se
    t_val <- cate / se
    p_val <- 2 * pnorm(-abs(t_val))
    
    cat(sprintf("  %s: %.4f (%.4f) [%.4f, %.4f] %s  N=%d\n",
                wealth_labels[as.character(q)], cate, se,
                ci_lo, ci_hi, ifelse(p_val < 0.05, "***", ""), length(idx)))
    
    results <- rbind(results, data.table(
      outcome = if_obj$outcome,
      treatment = if_obj$treatment,
      learner = if_obj$learner,
      subgroup = "wealth_quintile",
      subgroup_value = q,
      subgroup_label = wealth_labels[as.character(q)],
      cate = cate,
      se = se,
      ci_lower = ci_lo,
      ci_upper = ci_hi,
      t_stat = t_val,
      p_value = p_val,
      significant = ifelse(p_val < 0.05, "***", ""),
      N = length(idx)
    ))
  }
  
  # Test Q1 vs Q5
  ht <- test_heterogeneity(results, 1, 5)
  if (!is.null(ht)) {
    cat(sprintf("  Diff (Q1 - Q5): %.4f (%.4f), p=%.4f\n",
                ht$diff, ht$se_diff, ht$p_value))
  }
  
  all_cates <- rbind(all_cates, results)
}

# ==============================================================================
# 4. CATE BY SOURCE RISK
# ==============================================================================

cat("\n\n")
cat("############################################################\n")
cat("# CATE: SOURCE RISK LEVEL\n")
cat("############################################################\n")

source_risk_labels <- c("0" = "No Risk", "1" = "Moderate/High", "2" = "Very High")

for (if_obj in list(if_diarr_boil, if_ecoli_boil, if_some_boil)) {
  cat("\n--- Outcome:", if_obj$outcome, "| Treatment:", if_obj$treatment, "---\n")
  
  dat <- if_obj$dat
  phi <- if_obj$phi
  theta <- if_obj$theta
  
  # Source risk: src_no_risk, src_moderate, src_very_high
  # These variables are only in diarrhea model data
  risk_cols <- c("src_no_risk", "src_moderate", "src_very_high")
  
  has_source_risk <- all(risk_cols %in% colnames(dat))
  
  if (has_source_risk) {
    for (r in 1:3) {
      idx <- which(dat[[risk_cols[r]]] == 1)
      
      if (length(idx) < 10) next
      
      cate <- theta + mean(phi[idx])
      se <- sd(phi[idx]) / sqrt(length(idx))
      ci_lo <- cate - 1.96 * se
      ci_hi <- cate + 1.96 * se
      t_val <- cate / se
      p_val <- 2 * pnorm(-abs(t_val))
      
      cat(sprintf("  %s: %.4f (%.4f) [%.4f, %.4f] %s  N=%d\n",
                  source_risk_labels[as.character(r - 1)], cate, se,
                  ci_lo, ci_hi, ifelse(p_val < 0.05, "***", ""), length(idx)))
      
      all_cates <- rbind(all_cates, data.table(
        outcome = if_obj$outcome,
        treatment = if_obj$treatment,
        learner = if_obj$learner,
        subgroup = "RiskSource",
        subgroup_value = r - 1,
        subgroup_label = source_risk_labels[as.character(r - 1)],
        cate = cate,
        se = se,
        ci_lower = ci_lo,
        ci_upper = ci_hi,
        t_stat = t_val,
        p_value = p_val,
        significant = ifelse(p_val < 0.05, "***", ""),
        N = length(idx)
      ))
    }
    
    # Test No Risk vs Very High
    cat(sprintf("  Diff (Very High - No Risk): "))
    no_risk_idx <- which(dat$src_no_risk == 1)
    hi_risk_idx <- which(dat$src_very_high == 1)
    cate_no <- theta + mean(phi[no_risk_idx])
    cate_hi <- theta + mean(phi[hi_risk_idx])
    diff <- cate_hi - cate_no
    se_diff <- sqrt(var(phi[no_risk_idx])/length(no_risk_idx) + var(phi[hi_risk_idx])/length(hi_risk_idx))
    p_val <- 2 * pnorm(-abs(diff / se_diff))
    cat(sprintf("%.4f (%.4f), p=%.4f\n", diff, se_diff, p_val))
  } else {
    cat(sprintf("  (Source risk variables not in model data for this outcome)\n"))
  }
}

# ==============================================================================
# 5. SAVE RESULTS
# ==============================================================================

cat("\n\nSaving CATE results...\n")
saveRDS(all_cates, file.path(OUTPUT_DIR, "results_cates_extended.rds"))

# Export to CSV
fwrite(all_cates, file.path(OUTPUT_DIR, "results_cates_extended.csv"))
cat("Results saved to:\n")
cat("  ", file.path(OUTPUT_DIR, "results_cates_extended.rds"), "\n")
cat("  ", file.path(OUTPUT_DIR, "results_cates_extended.csv"), "\n")

# ==============================================================================
# 6. SUMMARY
# ==============================================================================

cat("\n\n")
cat("############################################################\n")
cat("# SUMMARY\n")
cat("############################################################\n")
cat("Method: Influence function decomposition\n")
cat("  CATE(g) = ATE + E[phi_i | i in g]\n")
cat("  SE(g)   = sd(phi_i | i in g) / sqrt(N_g)\n")
cat("\n")
cat("No models were re-estimated. All CATEs derived from the fitted\n")
cat("Stacked Ensemble models trained on the full sample.\n\n")

print(all_cates[, .(subgroup_label, outcome, cate, se, significant, N)])

cat("\n=== CATE ANALYSIS COMPLETE ===\n")
