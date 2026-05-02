#!/usr/bin/env Rscript
# ==============================================================================
# MICS DoubleML - Extract Stacked Weights (Final)
# ==============================================================================
# Extracts meta-learner coefficients from GraphLearner stacked ensembles
# by training on a sample of the data.
# ==============================================================================

suppressPackageStartupMessages({
  library(mlr3); library(mlr3pipelines); library(mlr3learners)
  library(haven); library(data.table); library(glmnet)
})

source("code/config.R")
source("code/data.R")
source("code/learners.R")

# --- Extract weights from trained GraphLearner ---
extract_gl_weights <- function(gl, meta_id) {
  meta_state <- gl$state$model[[meta_id]]
  if (is.null(meta_state) || is.null(meta_state$model)) return(NULL)
  cv_model <- meta_state$model
  if (!inherits(cv_model, "cv.glmnet")) return(NULL)
  
  coefs <- coef(cv_model, s = "lambda.min")
  w <- as.numeric(coefs)
  nm <- rownames(coefs)
  
  # Remove intercept
  idx <- nm != "(Intercept)"
  w <- w[idx]; nm <- nm[idx]
  
  # For classification, cv_glmnet returns one column per class
  # If matrix, take the column for the treatment class (usually last)
  if (is.matrix(w) || inherits(w, "Matrix")) {
    if (ncol(w) > 1) {
      # Take the column for class "1" (treatment)
      w <- w[, ncol(w)]
    } else {
      w <- as.numeric(w)
    }
  }
  if (is.matrix(nm) || inherits(nm, "Matrix")) nm <- rownames(coefs)[-1]
  
  # Clean names
  clean <- toupper(gsub("stack_(.+?)_[gm].*", "\\1", nm))
  clean <- gsub("LOG_REG", "OLS", clean)
  
  # Aggregate duplicate base learners (from multi-class)
  dt <- data.table(base_learner = clean, raw = w)
  dt <- dt[, .(raw = mean(raw)), by = base_learner]
  dt[, weight := abs(raw) / sum(abs(raw))]
  
  return(dt)
}

# --- Main ---
dt <- prepare_data(DATA_FILE)

# Prepare multi-treatment variables
dt[no_treatment == 1 | boil == 1 | chlorine == 1 | filter == 1 | other_treat == 1,
   `:=`(treat_boil = ifelse(boil == 1, 1L, 0L),
        treat_chlorine = ifelse(chlorine == 1, 1L, 0L),
        treat_filter = ifelse(filter == 1, 1L, 0L),
        treat_other = ifelse(other_treat == 1, 1L, 0L))]

configs <- list(
  # Diarrhea (source E.coli risk dummies included as confounders)
  list(key = "diarrhea_any_treatment",     outcome = "diarrhea",            treatment = "any_treatment",  ecoli = TRUE,  fn = create_stacked_ensemble),
  list(key = "diarrhea_treat_boil",        outcome = "diarrhea",            treatment = "treat_boil",    ecoli = TRUE,  fn = create_stacked_ensemble_no_ols),
  list(key = "diarrhea_treat_chlorine",    outcome = "diarrhea",            treatment = "treat_chlorine",ecoli = TRUE,  fn = create_stacked_ensemble_no_ols),
  list(key = "diarrhea_treat_filter",      outcome = "diarrhea",            treatment = "treat_filter",  ecoli = TRUE,  fn = create_stacked_ensemble_no_ols),
  list(key = "diarrhea_treat_other",       outcome = "diarrhea",            treatment = "treat_other",   ecoli = TRUE,  fn = create_stacked_ensemble_no_ols),
  # some_risk_home (source E.coli NOT included — mediator)
  list(key = "some_risk_home_any_treatment",     outcome = "some_risk_home",     treatment = "any_treatment",  ecoli = FALSE, fn = create_stacked_ensemble),
  list(key = "some_risk_home_treat_boil",        outcome = "some_risk_home",     treatment = "treat_boil",    ecoli = FALSE, fn = create_stacked_ensemble_no_ols),
  list(key = "some_risk_home_treat_chlorine",    outcome = "some_risk_home",     treatment = "treat_chlorine",ecoli = FALSE, fn = create_stacked_ensemble_no_ols),
  list(key = "some_risk_home_treat_filter",      outcome = "some_risk_home",     treatment = "treat_filter",  ecoli = FALSE, fn = create_stacked_ensemble_no_ols),
  list(key = "some_risk_home_treat_other",       outcome = "some_risk_home",     treatment = "treat_other",   ecoli = FALSE, fn = create_stacked_ensemble_no_ols),
  # very_high_risk_home (source E.coli NOT included — mediator)
  list(key = "very_high_risk_home_any_treatment",     outcome = "very_high_risk_home", treatment = "any_treatment",  ecoli = FALSE, fn = create_stacked_ensemble),
  list(key = "very_high_risk_home_treat_boil",        outcome = "very_high_risk_home", treatment = "treat_boil",    ecoli = FALSE, fn = create_stacked_ensemble_no_ols),
  list(key = "very_high_risk_home_treat_chlorine",    outcome = "very_high_risk_home", treatment = "treat_chlorine",ecoli = FALSE, fn = create_stacked_ensemble_no_ols),
  list(key = "very_high_risk_home_treat_filter",      outcome = "very_high_risk_home", treatment = "treat_filter",  ecoli = FALSE, fn = create_stacked_ensemble_no_ols),
  list(key = "very_high_risk_home_treat_other",       outcome = "very_high_risk_home", treatment = "treat_other",   ecoli = FALSE, fn = create_stacked_ensemble_no_ols)
)

all_weights <- list()

for (cfg in configs) {
  cat(sprintf("\n=== %s ===\n", cfg$key))
  
  tryCatch({
    dt_sub <- dt[!is.na(get(cfg$treatment))]
    X <- create_model_matrix(dt_sub, include_source_ecoli = cfg$ecoli)
    complete <- complete.cases(X) & !is.na(dt_sub[[cfg$outcome]]) & !is.na(dt_sub[[cfg$treatment]])
    dt_clean <- dt_sub[complete]
    X_clean <- X[complete, ]
    
    # Sample 3000 for speed
    set.seed(42)
    if (nrow(X_clean) > 3000) {
      idx <- sample(nrow(X_clean), 3000)
      dt_s <- dt_clean[idx]; X_s <- X_clean[idx, ]
    } else {
      dt_s <- dt_clean; X_s <- X_clean
    }
    
    stacked <- cfg$fn()
    
    # g model
    train_g <- data.frame(y = dt_s[[cfg$outcome]], d = dt_s[[cfg$treatment]], X_s)
    task_g <- as_task_regr(train_g, target = "y")
    stacked$g$train(task_g)
    g_w <- extract_gl_weights(stacked$g, "stack_meta_g")
    
    # m model
    train_m <- data.frame(d = as.factor(dt_s[[cfg$treatment]]), X_s)
    task_m <- as_task_classif(train_m, target = "d")
    stacked$m$train(task_m)
    m_w <- extract_gl_weights(stacked$m, "stack_meta_m")
    
    cat("  g:", paste(sprintf("%s=%.3f", g_w$base_learner, g_w$weight), collapse = ", "), "\n")
    cat("  m:", paste(sprintf("%s=%.3f", m_w$base_learner, m_w$weight), collapse = ", "), "\n")
    
    all_weights[[cfg$key]] <- list(g = g_w, m = m_w)
    
    # Free memory
    rm(stacked, task_g, task_m, train_g, train_m, dt_sub, dt_clean, X_clean, X, X_s, dt_s)
    gc()
    
  }, error = function(e) {
    cat("  ERROR:", e$message, "\n")
  })
}

saveRDS(all_weights, "Output/stacked_weights.rds")
cat("\n=== DONE ===\n")
cat("Saved to Output/stacked_weights.rds\n")
cat("Configs with weights:", length(all_weights), "\n")