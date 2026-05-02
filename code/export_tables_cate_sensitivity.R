# ==============================================================================
# MICS DoubleML - Export CATE and Sensitivity Tables to LaTeX
# ==============================================================================
# Reads:
#   Output/results_cates_extended.rds — CATEs by urban/rural, wealth, source risk
#   Output/sensitivity_analysis.rds   — Robustness values from run_sensitivity.R
#   Output/results_subgroups.rds      — Legacy RiskSource CATEs (old format)
# Writes to: Table/*.tex
# ==============================================================================

library(here)
library(data.table)
library(xtable)

source(here::here("code", "config.R"))

OUTPUT_DIR <- here::here("Output")
TABLE_DIR <- here::here("Table")
dir.create(TABLE_DIR, showWarnings = FALSE, recursive = TRUE)

# ==============================================================================
# TABLE 1: CATE BY SUBGROUPS (Influence Function Approach)
# ==============================================================================

cat("Loading CATE results...\n")

# Load extended CATEs (current format)
cate_file <- file.path(OUTPUT_DIR, "results_cates_extended.rds")

if (file.exists(cate_file)) {
  cate_extended <- readRDS(cate_file)

  # Filter to stacked ensemble only
  cate_stacked <- cate_extended[learner == "stacked"]

  if (nrow(cate_stacked) > 0) {

    # ======================================================================
    # TABLE 1A: CATE BY URBAN/RURAL
    # ======================================================================
    cate_urban <- cate_stacked[subgroup == "urban_bin"]

    if (nrow(cate_urban) > 0) {
      table_urban <- cate_urban[, .(
        Outcome = outcome,
        Location = subgroup_label,
        Effect = sprintf("%.4f", cate),
        SE = sprintf("%.4f", se),
        `95% CI` = sprintf("[%.4f, %.4f]", ci_lower, ci_upper),
        N = format(N, big.mark = ","),
        Sig = significant
      )]

      latex_urban <- xtable(table_urban,
                            caption = "Conditional Average Treatment Effects by Urban/Rural Location",
                            label = "tab:cate_urban")

      print(latex_urban,
            file = file.path(TABLE_DIR, "cate_urban_rural.tex"),
            booktabs = TRUE,
            include.rownames = FALSE,
            caption.placement = "top")
      cat("CATE Urban/Rural table saved → Table/cate_urban_rural.tex\n")
    }

    # ======================================================================
    # TABLE 1B: CATE BY WEALTH QUINTILE
    # ======================================================================
    cate_wealth <- cate_stacked[subgroup == "wealth_quintile"]

    if (nrow(cate_wealth) > 0) {
      table_wealth <- cate_wealth[, .(
        Outcome = outcome,
        Wealth = subgroup_label,
        Effect = sprintf("%.4f", cate),
        SE = sprintf("%.4f", se),
        `95% CI` = sprintf("[%.4f, %.4f]", ci_lower, ci_upper),
        N = format(N, big.mark = ","),
        Sig = significant
      )]

      latex_wealth <- xtable(table_wealth,
                             caption = "Conditional Average Treatment Effects by Wealth Quintile",
                             label = "tab:cate_wealth")

      print(latex_wealth,
            file = file.path(TABLE_DIR, "cate_wealth.tex"),
            booktabs = TRUE,
            include.rownames = FALSE,
            caption.placement = "top")
      cat("CATE Wealth table saved → Table/cate_wealth.tex\n")
    }

    # ======================================================================
    # TABLE 1C: CATE BY SOURCE RISK
    # ======================================================================
    cate_risksource <- cate_stacked[subgroup == "RiskSource"]

    if (nrow(cate_risksource) > 0) {
      table_risksource <- cate_risksource[, .(
        Outcome = outcome,
        `Source Risk` = subgroup_label,
        Effect = sprintf("%.4f", cate),
        SE = sprintf("%.4f", se),
        `95% CI` = sprintf("[%.4f, %.4f]", ci_lower, ci_upper),
        N = format(N, big.mark = ","),
        Sig = significant
      )]

      latex_risksource <- xtable(table_risksource,
                                 caption = "Conditional Average Treatment Effects by Source E.coli Contamination Level",
                                 label = "tab:cate_risksource")

      print(latex_risksource,
            file = file.path(TABLE_DIR, "cate_risksource.tex"),
            booktabs = TRUE,
            include.rownames = FALSE,
            caption.placement = "top")
      cat("CATE RiskSource table saved → Table/cate_risksource.tex\n")
    }

  } else {
    cat("WARNING: No stacked ensemble results found.\n")
  }
} else {
  cat("WARNING: results_cates_extended.rds not found.\n")
}

# ==============================================================================
# TABLE 2: SENSITIVITY ANALYSIS — Robustness Values
# ==============================================================================

cat("\nLoading sensitivity results...\n")

sensitivity_file <- file.path(OUTPUT_DIR, "sensitivity_analysis.rds")

if (file.exists(sensitivity_file)) {
  sensitivity <- readRDS(sensitivity_file)  # data.table

  # Map outcomes to readable labels
  outcome_labels <- c(
    "diarrhea"            = "Child Diarrhea",
    "very_high_risk_home" = "E. coli Very High Risk",
    "some_risk_home"      = "E. coli Any Risk"
  )
  sensitivity[, outcome_label := outcome_labels[outcome]]

  # Build formatted table
  table_sensitivity <- data.frame(
    Outcome = sensitivity$outcome_label,
    `DML ATE` = sprintf("%.4f", sensitivity$theta_dml),
    SE = sprintf("%.4f", sensitivity$se_dml),
    `t-stat` = sprintf("%.2f", sensitivity$t_stat),
    `Robustness Value` = sprintf("%.3f", sensitivity$rv_baseline),
    Interpretation = fifelse(
      sensitivity$rv_baseline > 0.2, "High",
      fifelse(sensitivity$rv_baseline > 0.1, "Moderate",
        fifelse(sensitivity$rv_baseline > 0.05, "Low", "Very Low"))),
    stringsAsFactors = FALSE
  )

  latex_sensitivity <- xtable(table_sensitivity,
                              caption = "Sensitivity Analysis: Robustness to Unobserved Confounding (RV)",
                              label = "tab:sensitivity")

  print(latex_sensitivity,
        file = file.path(TABLE_DIR, "sensitivity_analysis.tex"),
        booktabs = TRUE,
        include.rownames = FALSE,
        caption.placement = "top")
  cat("Sensitivity table saved → Table/sensitivity_analysis.tex\n")
}

# ==============================================================================
# COMBINED CATE TABLE (CSV export for reference)
# ==============================================================================

cat("\nCreating combined CATE table...\n")

if (exists("cate_stacked") && nrow(cate_stacked) > 0) {

  combined_table <- cate_stacked[, .(
    Subgroup    = subgroup_label,
    Outcome     = outcome,
    Treatment   = treatment,
    `CATE`      = cate,
    SE          = se,
    `CI Lower`  = ci_lower,
    `CI Upper`  = ci_upper,
    N           = N,
    Sig         = significant
  )]

  combined_table[, `Effect (SE)` := sprintf("%.4f (%.4f)%s", CATE, SE, Sig)]

  setorder(combined_table, Subgroup, Outcome)

  cat("\nCombined CATE table:\n")
  print(combined_table[, .(Subgroup, Outcome, `Effect (SE)`, N)])

  write.csv(combined_table, file.path(OUTPUT_DIR, "cate_combined.csv"), row.names = FALSE)
  cat("\nSaved → Output/cate_combined.csv\n")
}

cat("\n=== TABLE EXPORT COMPLETE ===\n")
