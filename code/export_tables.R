# ==============================================================================
# MICS DoubleML - Export Tables (v3 — Weights from stacked_weights.rds)
# ==============================================================================
# Generates publication-ready LaTeX tables with:
#   - Coefficients with SE in parentheses
#   - Stacked ensemble weights (g and m) from pre-extracted stacked_weights.rds
#   - OLS included only for Any Treatment panel
#   - OLS shown as "---" for specific treatment panels (quasi-complete separation)
#   - Footnote explaining OLS exclusion
# ==============================================================================

library(DoubleML)
library(data.table)

source("code/config.R")

# ==============================================================================
# LOAD PRE-EXTRACTED WEIGHTS
# ==============================================================================

load_stacked_weights <- function(weights_file = file.path(OUTPUT_DIR, "stacked_weights.rds")) {
  if (!file.exists(weights_file)) {
    cat("Warning: stacked_weights.rds not found. Weights will not be shown.\n")
    return(NULL)
  }
  readRDS(weights_file)
}

get_weights_for_config <- function(all_weights, outcome, treatment) {
  # Map outcome/treatment to the key in stacked_weights.rds
  # Keys: "diarrhea_any_treatment", "diarrhea_treat_boil", etc.
  key <- paste(outcome, treatment, sep = "_")
  
  if (is.null(all_weights) || !key %in% names(all_weights)) return(NULL)
  
  all_weights[[key]]
}

# ==============================================================================
# LOAD ALL RESULTS FROM CHECKPOINTS
# ==============================================================================

load_all_results <- function(checkpoint_dir = CHECKPOINT_DIR) {
  files <- list.files(checkpoint_dir, pattern = "\\.rds$", full.names = TRUE)
  
  results <- rbindlist(lapply(files, function(f) {
    obj <- readRDS(f)
    data.table(
      outcome = obj$outcome,
      treatment = obj$treatment,
      learner = obj$learner,
      subgroup_var = ifelse(is.null(obj$subgroup_var), "full", obj$subgroup_var),
      coef = obj$coef,
      se = obj$se,
      ci_lower = obj$ci_lower,
      ci_upper = obj$ci_upper,
      n = obj$n,
      pval = obj$pval
    )
  }), fill = TRUE)
  
  return(results)
}

# ==============================================================================
# GENERATE LATEX TABLE
# ==============================================================================

generate_latex_table <- function(results, outcome_var, subgroup = "full", 
                                   all_weights = NULL,
                                   output_file = NULL) {
  # Generate LaTeX table for one outcome
  # OLS included for Any Treatment, excluded (---) for specific treatments
  
  dt <- results[outcome == outcome_var & subgroup_var == subgroup]
  
  if (nrow(dt) == 0) {
    warning("No results found for outcome: ", outcome_var, " subgroup: ", subgroup)
    return(invisible(NULL))
  }
  
  # All possible learners/labels
  all_learners <- c("ols", "lasso", "ridge", "enet", "rf", "xgb", "stacked")
  all_labels <- c("OLS", "Lasso", "Ridge", "ENet", "RF", "XGB", "Stacked")
  
  # Treatment order (panels)
  treatment_order <- c("any_treatment", "treat_boil", "treat_chlorine", "treat_filter", "treat_other")
  treatment_labels <- c("Any Treatment", "Boil (vs Control)", "Chlorine (vs Control)", 
                        "Filter (vs Control)", "Other (vs Control)")
  
  # Significance stars
  get_stars <- function(pval) {
    if (is.na(pval)) return("")
    if (pval < 0.001) return("***")
    if (pval < 0.01) return("**")
    if (pval < 0.05) return("*")
    if (pval < 0.1) return(".")
    return("")
  }
  
  format_weight <- function(w) {
    if (is.na(w) || is.null(w)) return("")
    sprintf("%.2f", w)
  }
  
  # Map learner name to weight base_learner name
  learner_to_weight_name <- function(ln) {
    switch(ln,
      ols = "OLS",
      lasso = "LASSO",
      ridge = "RIDGE",
      enet = "ENET",
      rf = "RF",
      xgb = "XGB",
      stacked = "Stacked",
      NA)
  }
  
  # Determine which panels exist
  existing_treatments <- intersect(treatment_order, unique(dt$treatment))
  
  # Outcome labels
  outcome_labels <- c(
    "diarrhea" = "Child Diarrhea",
    "some_risk_home" = "Any Detectable E.coli at Home",
    "very_high_risk_home" = "Very High E.coli at Home (>100 CFU/100ml)"
  )
  
  # Build LaTeX
  lines <- character()
  
  lines <- c(lines, "\\begin{table}[htbp]")
  lines <- c(lines, "\\centering")
  lines <- c(lines, sprintf("\\caption{Effect of Water Treatment on %s}", 
                            ifelse(outcome_var == "diarrhea", "Child Diarrhea", 
                                   ifelse(outcome_var == "some_risk_home", "Any Detectable E.coli at Home ($WQ26>0$)",
                                          "Very High E.coli at Home ($WQ26>100$ CFU/100ml)"))))
  lines <- c(lines, sprintf("\\label{tab:%s_%s}", outcome_var, subgroup))
  lines <- c(lines, "\\begin{tabular}{lccccccc}")
  lines <- c(lines, "\\toprule")
  
  # Header row
  lines <- c(lines, sprintf(" & %s \\\\", paste(all_labels, collapse = " & ")))
  lines <- c(lines, "\\midrule")
  
  panel_idx <- 0
  for (i in seq_along(treatment_order)) {
    treat <- treatment_order[i]
    treat_label <- treatment_labels[i]
    dt_treat <- dt[treatment == treat]
    
    if (nrow(dt_treat) == 0) next
    panel_idx <- panel_idx + 1
    
    # Determine if OLS should be shown as --- or real value
    ols_excluded <- (treat != "any_treatment")
    
    lines <- c(lines, sprintf("\\multicolumn{8}{l}{\\textbf{Panel %s: %s}} \\\\", 
                              LETTERS[panel_idx], treat_label))
    lines <- c(lines, "\\midrule")
    
    # Coefficients row
    coef_row <- character()
    for (ln in all_learners) {
      row <- dt_treat[learner == ln]
      if (nrow(row) == 0) {
        if (ols_excluded && ln == "ols") {
          coef_row <- c(coef_row, "---")
        } else {
          coef_row <- c(coef_row, "—")
        }
      } else if (ols_excluded && ln == "ols") {
        coef_row <- c(coef_row, "---")
      } else {
        stars <- get_stars(row$pval)
        coef_row <- c(coef_row, sprintf("%.4f%s", row$coef, stars))
      }
    }
    lines <- c(lines, sprintf("Coefficient & %s \\\\", paste(coef_row, collapse = " & ")))
    
    # SE row
    se_row <- character()
    for (ln in all_learners) {
      if (ols_excluded && ln == "ols") {
        se_row <- c(se_row, "")
      } else {
        row <- dt_treat[learner == ln]
        if (nrow(row) == 0) {
          se_row <- c(se_row, "")
        } else {
          se_row <- c(se_row, sprintf("(%.4f)", row$se))
        }
      }
    }
    lines <- c(lines, sprintf(" & %s \\\\", paste(se_row, collapse = " & ")))
    
    # Stacked weights (only if stacked result exists and we have weights)
    stacked_row <- dt_treat[learner == "stacked"]
    if (nrow(stacked_row) > 0 && !is.null(all_weights)) {
      weights <- get_weights_for_config(all_weights, outcome_var, treat)
      
      if (!is.null(weights)) {
        # g weights
        w_g_row <- character()
        for (ln in all_learners) {
          if (ln == "stacked") {
            w_g_row <- c(w_g_row, "—")
          } else if (ols_excluded && ln == "ols") {
            w_g_row <- c(w_g_row, "")
          } else {
            bl <- learner_to_weight_name(ln)
            w <- weights$g[base_learner == bl, weight]
            if (length(w) > 0 && !is.na(w)) {
              w_g_row <- c(w_g_row, format_weight(w))
            } else {
              w_g_row <- c(w_g_row, "")
            }
          }
        }
        lines <- c(lines, sprintf("Weight $(g)$ & %s \\\\", paste(w_g_row, collapse = " & ")))
        
        # m weights
        w_m_row <- character()
        for (ln in all_learners) {
          if (ln == "stacked") {
            w_m_row <- c(w_m_row, "—")
          } else if (ols_excluded && ln == "ols") {
            w_m_row <- c(w_m_row, "")
          } else {
            bl <- learner_to_weight_name(ln)
            w <- weights$m[base_learner == bl, weight]
            if (length(w) > 0 && !is.na(w)) {
              w_m_row <- c(w_m_row, format_weight(w))
            } else {
              w_m_row <- c(w_m_row, "")
            }
          }
        }
        lines <- c(lines, sprintf("Weight $(m)$ & %s \\\\", paste(w_m_row, collapse = " & ")))
      }
    }
    
    lines <- c(lines, "")
  }
  
  # Observations
  n_obs <- dt[treatment == "any_treatment", max(n)]
  if (is.na(n_obs) || is.infinite(n_obs)) {
    n_obs <- dt[, max(n)]
  }
  lines <- c(lines, "\\midrule")
  lines <- c(lines, sprintf("Observations & \\multicolumn{7}{c}{%s} \\\\", format(n_obs, big.mark = ",")))
  lines <- c(lines, "\\bottomrule")
  lines <- c(lines, "\\end{tabular}")
  
  # Footnotes
  lines <- c(lines, "\\begin{minipage}{\\textwidth}")
  lines <- c(lines, "\\footnotesize")
  lines <- c(lines, "\\textit{Notes:} DoubleML IRM estimates with 5-fold cross-validation, 2 repetitions. ")
  lines <- c(lines, "Standard errors in parentheses. ")
  lines <- c(lines, "Controls: wealth quintiles, education, urban, sanitation, water source FE, country FE. ")
  if (outcome_var == "diarrhea") {
    lines <- c(lines, "Source E.coli risk dummies (no/moderate/very high) included as confounders. ")
  } else {
    lines <- c(lines, "Source E.coli not included (potential mediator for home E.coli). ")
  }
  lines <- c(lines, "OLS estimates (---) excluded from specific treatment panels due to quasi-complete separation: ")
  lines <- c(lines, "country fixed effects perfectly predict zero treatment in several countries (e.g., Benin and Central African Republic have 0\\% boil rate), ")
  lines <- c(lines, "causing infinite MLE in the logistic propensity model and rank-deficient fits in the outcome model. ")
  lines <- c(lines, "Regularized learners (Lasso, Ridge, ENet) are unaffected as penalties prevent coefficient divergence. ")
  lines <- c(lines, "Stacked ensemble for specific treatments uses only 5 base learners (Lasso, Ridge, ENet, RF, XGB) to avoid OLS contamination. ")
  lines <- c(lines, "Stacked weights are normalized absolute coefficients from the ridge meta-learner. ")
  lines <- c(lines, "$^{***}p<0.001$, $^{**}p<0.01$, $^{*}p<0.05$, $^{.}p<0.1$")
  lines <- c(lines, "\\end{minipage}")
  lines <- c(lines, "\\end{table}")
  
  # Write to file or return
  if (!is.null(output_file)) {
    writeLines(lines, output_file)
    cat("Table saved to:", output_file, "\n")
  }
  
  return(lines)
}

# ==============================================================================
# GENERATE ALL TABLES
# ==============================================================================

generate_all_tables <- function(output_dir = OUTPUT_DIR) {
  cat("Loading results from checkpoints...\n")
  results <- load_all_results()
  
  cat("\nLoading pre-extracted stacked weights...\n")
  all_weights <- load_stacked_weights()
  
  cat("\nResults summary:\n")
  print(unique(results[, .(outcome, treatment, learner, subgroup_var)]))
  
  dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
  
  # Main tables (full sample)
  cat("\n=== Generating main tables ===\n")
  generate_latex_table(results, "diarrhea", "full", all_weights,
                       file.path(output_dir, "table_diarrhea.tex"))
  generate_latex_table(results, "some_risk_home", "full", all_weights,
                       file.path(output_dir, "table_some_risk_home.tex"))
  generate_latex_table(results, "very_high_risk_home", "full", all_weights,
                       file.path(output_dir, "table_very_high_risk_home.tex"))
  
  # Subgroup tables (if data exists)
  cat("\n=== Generating subgroup tables ===\n")
  for (subgroup_val in c("0", "1", "2")) {
    subgroup_label <- c("0" = "norisk", "1" = "moderate", "2" = "high")[subgroup_val]
    
    generate_latex_table(results, "diarrhea", subgroup_val, all_weights,
                         file.path(output_dir, sprintf("table_diarrhea_%s.tex", subgroup_label)))
    generate_latex_table(results, "some_risk_home", subgroup_val, all_weights,
                         file.path(output_dir, sprintf("table_some_risk_home_%s.tex", subgroup_label)))
    generate_latex_table(results, "very_high_risk_home", subgroup_val, all_weights,
                         file.path(output_dir, sprintf("table_very_high_risk_home_%s.tex", subgroup_label)))
  }
  
  saveRDS(results, file.path(output_dir, "all_results.rds"))
  cat("\nAll results saved to:", file.path(output_dir, "all_results.rds"), "\n")
}

# ==============================================================================
# MAIN
# ==============================================================================

if (!interactive()) {
  generate_all_tables()
}