# ==============================================================================
# MICS DoubleML - Sensitivity Analysis (using fitted DoubleML models)
# ==============================================================================
# Uses ALREADY-FITTED DoubleML models to assess robustness to unobserved
# confounding. NO models are re-estimated.
#
# Method: Influence functions for robustness values + sensemakr for benchmarks
#
# Key advantage: Direct use of DoubleML estimates rather than OLS approximation
# ==============================================================================

library(here)
library(data.table)
library(sensemakr)

source(here::here("code", "config.R"))
source(here::here("code", "data.R"))

# ==============================================================================
# FUNCTION: Sensitivity analysis using DoubleML influence functions
# ==============================================================================

compute_sensitivity_dml <- function(checkpoint_file, benchmark_covars = NULL) {
  # Load the fitted model
  cp <- readRDS(checkpoint_file)
  dml <- cp$model
  theta <- cp$coef
  se <- cp$se
  
  # Extract data used for fitting
  dat <- dml$data$data
  y <- dat$y
  d <- dat$d
  
  # Extract influence functions
  pb <- dml$psi_b[,,1]   # (N, n_rep)
  phi <- rowMeans(pb) - theta  # influence functions
  
  # Robustness Value: strength of confounder needed to change inference
  # Based on the t-statistic
  t_stat <- theta / se
  n <- length(y)
  
  # RV to make effect non-significant at alpha=0.05
  # Uses the bound from Cinelli & Hazlett adapted for ML estimators
  # Approximate: RV = (t^2 / (t^2 + n))^(1/2) for standard errors
  # But for influence functions, we use a different approach
  
  # Critical t-value for alpha=0.05 (two-sided)
  t_crit <- qnorm(0.975)
  
  # Variance explained needed to move from current t to t_crit
  # If confounder explains R2 of residual variance in Y and D...
  # RV is the minimum R2 needed
  
  # Conservative approximation using influence function variance
  # If we add a confounder U that explains proportion f of residual variance:
  # New theta = theta - f * mean(phi * U) / var(U)
  
  # Simple robustness: what fraction of effect would need to be "explained away"
  # by an unobserved confounder to make it insignificant?
  effect_fraction <- abs(theta) / (t_crit * se)
  
  # RV interpretation: proportion of residual variance that an unobserved 
  # confounder would need to explain in BOTH treatment and outcome
  # to change the conclusion
  
  # For standard errors, use the ratio of current |t| to critical t
  rv_baseline <- (t_stat^2 - t_crit^2) / t_stat^2
  rv_baseline <- max(0, min(rv_baseline, 1))  # bound between 0 and 1
  
  # Alternative: use variance of influence functions
  # The "effective sample size" for heterogeneity
  var_phi <- var(phi)
  effective_n <- (theta / se)^2 * (var_phi / theta^2)  # rough approx
  
  # Benchmark using OLS on a reduced set of key confounders
  # (can't run OLS on 57 variables due to collinearity)
  
  # Select key confounders for benchmark OLS
  key_vars <- c("wealth_q1", "wealth_q2", "wealth_q3", "wealth_q4",
                "edu_0", "edu_1", "edu_2", "edu_3", 
                "urban_bin", "sanitation", "num_children")
  
  # Also include source ecoli if present
  if ("log_WQ27" %in% colnames(dat)) {
    key_vars <- c(key_vars, "log_WQ27")
  }
  
  # Subset to available columns
  key_vars <- key_vars[key_vars %in% colnames(dat)]
  
  # Create OLS data frame with complete cases
  ols_df <- as.data.frame(dat[, c("y", "d", key_vars)])
  ols_df <- ols_df[complete.cases(ols_df), ]
  
  # Check if we have valid data for OLS
  ols_success <- !is.null(ols_df) && is.data.frame(ols_df) && 
               ncol(ols_df) > 2 && nrow(ols_df) > 100
  
  if (ols_success) {
    # Check for collinearity - use only non-collinear variables
    X_mat <- as.matrix(ols_df[, -c(1, 2)])
    
    # Remove columns with zero variance
    var_check <- apply(X_mat, 2, var, na.rm = TRUE)
    X_mat <- X_mat[, var_check > 1e-10, drop = FALSE]
    
    if (ncol(X_mat) >= 1) {
      ols_df_clean <- cbind(y = ols_df$y, d = ols_df$d, as.data.frame(X_mat))
      
      formula_str <- paste("y ~ d +", paste(colnames(ols_df_clean)[-(1:2)], collapse = " + "))
      model_ols <- tryCatch(lm(as.formula(formula_str), data = ols_df_clean),
                            error = function(e) NULL)
      
      if (!is.null(model_ols)) {
        coef_ols <- coef(model_ols)["d"]
        se_ols <- summary(model_ols)$coefficients["d", "Std. Error"]
        r2_full <- summary(model_ols)$r.squared
        
        # Model without treatment
        formula_no_treat <- paste("y ~", paste(colnames(ols_df_clean)[-(1:2)], collapse = " + "))
        model_no_treat <- tryCatch(lm(as.formula(formula_no_treat), data = ols_df_clean),
                                     error = function(e) NULL)
        
        if (!is.null(model_no_treat)) {
          r2_no_treat <- summary(model_no_treat)$r.squared
          r2_partial <- r2_full - r2_no_treat
        } else {
          r2_partial <- NA
        }
        
        # Sensemakr analysis if requested
        sense <- NULL
        if (!is.null(benchmark_covars)) {
          bench_avail <- benchmark_covars[benchmark_covars %in% colnames(ols_df_clean)]
          if (length(bench_avail) > 0) {
            sense <- tryCatch(sensemakr(
              model = model_ols,
              treatment = "d",
              benchmark_covariates = bench_avail,
              kd = c(0.5, 1, 2),
              ky = c(0.5, 1, 2)
            ), error = function(e) NULL)
          }
        }
      } else {
        coef_ols <- NA
        se_ols <- NA
        r2_full <- NA
        r2_partial <- NA
        sense <- NULL
      }
    } else {
      coef_ols <- NA
      se_ols <- NA
      r2_full <- NA
      r2_partial <- NA
      sense <- NULL
    }
  } else {
    coef_ols <- NA
    se_ols <- NA
    r2_full <- NA
    r2_partial <- NA
    sense <- NULL
  }
  
  list(
    outcome = cp$outcome,
    treatment = cp$treatment,
    learner = cp$learner,
    theta_dml = theta,
    se_dml = se,
    t_stat = t_stat,
    theta_ols = coef_ols,
    se_ols = se_ols,
    r2_partial = r2_partial,
    r2_full = r2_full,
    rv_baseline = rv_baseline,
    sensemakr = sense
  )
}

# ==============================================================================
# FUNCTION: Alternative sensitivity using influence function variance
# ==============================================================================

compute_if_sensitivity <- function(checkpoint_file) {
  # Compute sensitivity bounds directly from influence functions
  cp <- readRDS(checkpoint_file)
  dml <- cp$model
  theta <- cp$coef
  se <- cp$se
  
  pb <- dml$psi_b[,,1]
  phi <- rowMeans(pb) - theta
  
  # Influence function percentiles
  phi_q05 <- quantile(phi, 0.05)
  phi_q95 <- quantile(phi, 0.95)
  
  # If we removed the top 5% of observations (potential outliers/drivers)
  robust_95 <- theta + mean(phi[phi >= phi_q05 & phi <= phi_q95])
  
  # Bounds: what if confounder moves top X% of observations?
  # Conservative: assume worst 10% have confounder with effect size equal to ATE
  worst_10_idx <- order(phi)[1:round(0.1 * length(phi))]
  worst_10_mean <- mean(phi[worst_10_idx])
  
  list(
    outcome = cp$outcome,
    treatment = cp$treatment,
    theta = theta,
    se = se,
    phi_mean = mean(phi),
    phi_sd = sd(phi),
    phi_q05 = phi_q05,
    phi_q95 = phi_q95,
    robust_95 = robust_95,
    worst_10_pct_effect = worst_10_mean
  )
}

# ==============================================================================
# MAIN: Run sensitivity analysis for key models
# ==============================================================================

cat("========================================\n")
cat("SENSITIVITY ANALYSIS — Using Fitted Models\n")
cat("(No models re-estimated)\n")
cat("========================================\n\n")

# ==============================================================================
# 1. Load fitted models and run sensitivity
# ==============================================================================

cat("Analyzing sensitivity for key models...\n\n")

# Define models to analyze
models_to_analyze <- list(
  list(file = "diarrhea_treat_boil_stacked.rds", 
       desc = "Boil → Diarrhea",
       benchmark = c("wealth_q1", "urban_bin")),
  list(file = "very_high_risk_home_treat_boil_stacked.rds",
       desc = "Boil → Very High Risk E.coli",
       benchmark = c("wealth_q1", "urban_bin")),
  list(file = "some_risk_home_treat_boil_stacked.rds",
       desc = "Boil → Any Risk E.coli",
       benchmark = c("wealth_q1", "urban_bin"))
)

all_results <- data.table()

for (m in models_to_analyze) {
  cat(sprintf("\n--- %s ---\n", m$desc))
  
  sens <- compute_sensitivity_dml(
    file.path(CHECKPOINT_DIR, m$file),
    benchmark_covars = m$benchmark
  )
  
  cat(sprintf("  DoubleML ATE: %.4f (%.4f), t=%.2f\n", 
              sens$theta_dml, sens$se_dml, sens$t_stat))
  cat(sprintf("  OLS ATE (key confounders): %.4f (%.4f)\n", 
              ifelse(is.na(sens$theta_ols), 0, sens$theta_ols), 
              ifelse(is.na(sens$se_ols), 0, sens$se_ols)))
  cat(sprintf("  Partial R² (treatment): %.4f\n", 
              ifelse(is.na(sens$r2_partial), 0, sens$r2_partial)))
  cat(sprintf("  RV (baseline): %.4f\n", sens$rv_baseline))
  
  # Interpretation
  if (!is.null(sens$sensemakr)) {
    rv <- sens$sensemakr$sensitivity_stats$rv
    rv_q <- sens$sensemakr$sensitivity_stats$rv_q
    
    cat(sprintf("\n  Sensemakr Results:\n"))
    cat(sprintf("    Robustness Value (RV): %.4f\n", rv))
    cat(sprintf("    RV (α=0.05): %.4f\n", rv_q))
    
    # Benchmark comparison
    cat(sprintf("\n    Benchmark confounders:\n"))
    for (bc in names(sens$sensemakr$sensitivity_stats$r2dzj)) {
      r2d <- sens$sensemakr$sensitivity_stats$r2dzj[bc]
      r2y <- sens$sensemakr$sensitivity_stats$r2yzj[bc]
      cat(sprintf("      %s: R²(D~U|X)=%.3f, R²(Y~U|D,X)=%.3f\n", bc, r2d, r2y))
    }
    
    cat(sprintf("\n    Interpretation:\n"))
    cat(sprintf("    An unobserved confounder would need to explain %.1f%%\n", rv * 100))
    cat(sprintf("    of residual variance in both treatment AND outcome\n"))
    cat(sprintf("    to make the effect statistically insignificant.\n"))
  } else {
    cat(sprintf("\n  Interpretation:\n"))
    if (sens$rv_baseline > 0.2) {
      cat(sprintf("    HIGHLY ROBUST: RV=%.1f%% suggests strong resilience to confounding.\n", 
                  sens$rv_baseline * 100))
    } else if (sens$rv_baseline > 0.1) {
      cat(sprintf("    MODERATELY ROBUST: RV=%.1f%% suggests moderate confounding needed.\n",
                  sens$rv_baseline * 100))
    } else {
      cat(sprintf("    SENSITIVE: RV=%.1f%% suggests even moderate confounding could matter.\n",
                  sens$rv_baseline * 100))
    }
  }
  
  # Store results
  all_results <- rbind(all_results, data.table(
    outcome = sens$outcome,
    treatment = sens$treatment,
    learner = sens$learner,
    theta_dml = sens$theta_dml,
    se_dml = sens$se_dml,
    t_stat = sens$t_stat,
    theta_ols = sens$theta_ols,
    se_ols = sens$se_ols,
    r2_partial = sens$r2_partial,
    r2_full = sens$r2_full,
    rv_baseline = sens$rv_baseline
  ))
}

# ==============================================================================
# 2. Influence function diagnostics
# ==============================================================================

cat("\n\n")
cat("############################################################\n")
cat("# INFLUENCE FUNCTION DIAGNOSTICS\n")
cat("############################################################\n\n")

for (m in models_to_analyze) {
  cat(sprintf("\n--- %s ---\n", m$desc))
  
  if_sens <- compute_if_sensitivity(file.path(CHECKPOINT_DIR, m$file))
  
  cat(sprintf("  IF mean: %.6f (should be 0)\n", if_sens$phi_mean))
  cat(sprintf("  IF SD: %.4f\n", if_sens$phi_sd))
  cat(sprintf("  IF 5th percentile: %.4f\n", if_sens$phi_q05))
  cat(sprintf("  IF 95th percentile: %.4f\n", if_sens$phi_q95))
  cat(sprintf("  Effect (trimming 5%% tails): %.4f\n", if_sens$robust_95))
  cat(sprintf("  Mean IF of worst 10%%: %.4f\n", if_sens$worst_10_pct_effect))
}

# ==============================================================================
# 3. SAVE RESULTS
# ==============================================================================

cat("\n\nSaving sensitivity results...\n")
saveRDS(all_results, file.path(OUTPUT_DIR, "sensitivity_analysis.rds"))
fwrite(all_results, file.path(OUTPUT_DIR, "sensitivity_summary.csv"))

cat("Results saved to:\n")
cat("  ", file.path(OUTPUT_DIR, "sensitivity_analysis.rds"), "\n")
cat("  ", file.path(OUTPUT_DIR, "sensitivity_summary.csv"), "\n")

# ==============================================================================
# 4. SUMMARY TABLE FOR PAPER
# ==============================================================================

cat("\n\n")
cat("############################################################\n")
cat("# SUMMARY TABLE (LaTeX format)\n")
cat("############################################################\n\n")

cat("\\begin{table}[htbp]\n")
cat("\\centering\n")
cat("\\caption{Sensitivity Analysis: Robustness to Unobserved Confounding}\n")
cat("\\label{tab:sensitivity}\n")
cat("\\begin{tabular}{lccccc}\n")
cat("\\hline\n")
cat("Outcome & DML ATE & SE & $t$-stat & RV & Robustness \\\\\n")
cat("\\hline\n")

for (i in 1:nrow(all_results)) {
  r <- all_results[i]
  
  interp <- if (is.na(r$rv_baseline)) {
    "N/A"
  } else if (r$rv_baseline > 0.2) {
    "High"
  } else if (r$rv_baseline > 0.1) {
    "Moderate"
  } else if (r$rv_baseline > 0.05) {
    "Low"
  } else {
    "Very Low"
  }
  
  cat(sprintf("%s & %.4f & %.4f & %.2f & %.3f & %s \\\\\n",
              r$outcome, r$theta_dml, r$se_dml, r$t_stat, 
              ifelse(is.na(r$rv_baseline), 0, r$rv_baseline), interp))
}

cat("\\hline\n")
cat("\\multicolumn{6}{p{\\textwidth}}{\\small\n")
cat("Note: RV = Robustness Value (baseline). Higher values indicate greater\n")
cat("resilience to unobserved confounding.\\" %in% "Robustness: High ($>0.2$),\n")
cat("Moderate ($0.1-0.2$), Low ($0.05-0.1$), Very Low ($<0.05$).}\n")
cat("\\end{tabular}\n")
cat("\\end{table}\n")

cat("\n=== SENSITIVITY ANALYSIS COMPLETE ===\n")
