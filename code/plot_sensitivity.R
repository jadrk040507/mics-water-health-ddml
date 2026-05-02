# ==============================================================================
# MICS DoubleML - Sensitivity Plots
# ==============================================================================
# Generates visualizations for sensitivity analysis using already-fitted models.
# Reads checkpoints and saved sensitivity results, produces publication-quality
# plots for:
#   1. RV contour plots (sensemakr-style)
#   2. Influence function distributions
#   3. Benchmark comparisons
# ==============================================================================

library(here)
library(data.table)
library(sensemakr)
library(ggplot2)
library(gridExtra)

source(here::here("code", "config.R"))

OUTPUT_DIR <- here::here("Output")
FIGURE_DIR <- here::here("Figures")
dir.create(FIGURE_DIR, showWarnings = FALSE, recursive = TRUE)

# ==============================================================================
# HELPER: Load checkpoint and extract influence functions
# ==============================================================================

load_checkpoint <- function(checkpoint_file) {
  cp <- readRDS(checkpoint_file)
  dml <- cp$model
  theta <- cp$coef
  se <- cp$se
  
  pb <- dml$psi_b[,,1]
  phi <- rowMeans(pb) - theta
  
  list(
    outcome = cp$outcome,
    treatment = cp$treatment,
    theta = theta,
    se = se,
    phi = phi,
    n = cp$n,
    label = sprintf("%s → %s", cp$treatment, cp$outcome)
  )
}

# ==============================================================================
# PLOT 1: Influence Function Distribution
# ==============================================================================

plot_if_distribution <- function(if_obj) {
  phi <- if_obj$phi
  theta <- if_obj$theta
  se <- if_obj$se
  
  df <- data.table(phi = phi)
  
  p <- ggplot(df, aes(x = phi)) +
    geom_histogram(aes(y = after_stat(density)), bins = 60,
                   fill = "#2c3e50", alpha = 0.7, color = "white", size = 0.3) +
    geom_density(color = "#e74c3c", linewidth = 1) +
    geom_vline(xintercept = 0, linetype = "dashed", color = "#7f8c8d", size = 0.5) +
    geom_vline(xintercept = theta, linetype = "solid", color = "#2980b9", size = 1) +
    annotate("text", x = theta, y = Inf, label = sprintf("ATE = %.4f", theta),
             hjust = ifelse(theta > 0, 0, 1), vjust = 2, color = "#2980b9", size = 3.5) +
    labs(
      title = sprintf("Influence Function Distribution: %s", if_obj$label),
      subtitle = sprintf("N = %s | SE = %.4f | RV = %.3f",
                         format(if_obj$n, big.mark = ","), se,
                         (if_obj$theta^2 / if_obj$se^2 - qnorm(0.975)^2) / (if_obj$theta^2 / if_obj$se^2)),
      x = "Influence Function (φᵢ)",
      y = "Density"
    ) +
    theme_minimal(base_size = 12) +
    theme(
      plot.title = element_text(face = "bold"),
      plot.subtitle = element_text(color = "gray40", size = 10),
      panel.grid.minor = element_blank()
    )
  
  return(p)
}

# ==============================================================================
# PLOT 2: RV Contour Plot (sensemakr-style)
# ==============================================================================

plot_rv_contour <- function(sens_obj, title = NULL) {
  # Use sensemakr's built-in contour plot
  p <- plot(sens_obj, 
            type = "contour",
            cex.lab = 0.9,
            cex.axis = 0.8,
            cex.main = 0.9)
  
  # sensemakr returns a base R plot; capture as a ggplot-like object
  # We'll save it directly in the calling code
  return(p)
}

# ==============================================================================
# PLOT 3: RV Comparison Bar Chart
# ==============================================================================

plot_rv_comparison <- function(all_sensitivity) {
  # all_sensitivity is a data.table with columns: outcome, rv_baseline
  df <- all_sensitivity[, .(
    Model = gsub("_", " ", outcome),
    RV = round(rv_baseline * 100, 1)
  )]
  
  df[, Model := factor(Model, levels = Model[order(RV)])]
  
  p <- ggplot(df, aes(x = Model, y = RV, fill = RV > 20)) +
    geom_col(width = 0.6, alpha = 0.85, color = "white", size = 0.5) +
    geom_text(aes(label = sprintf("%.1f%%", RV)),
              hjust = -0.15, size = 4, fontface = "bold") +
    scale_fill_manual(values = c("TRUE" = "#27ae60", "FALSE" = "#e67e22")) +
    coord_flip() +
    scale_y_continuous(limits = c(0, 110), expand = c(0, 0)) +
    labs(
      title = "Robustness Value Comparison",
      subtitle = "Higher RV = more resilient to unobserved confounding",
      x = NULL,
      y = "Robustness Value (%)"
    ) +
    theme_minimal(base_size = 13) +
    theme(
      plot.title = element_text(face = "bold"),
      plot.subtitle = element_text(color = "gray40", size = 10),
      legend.position = "none",
      panel.grid.major.y = element_blank(),
      panel.grid.minor = element_blank()
    )
  
  return(p)
}

# ==============================================================================
# PLOT 4: OLS vs DML Comparison
# ==============================================================================

plot_ols_dml_comparison <- function(all_sensitivity) {
  df <- all_sensitivity[!is.na(theta_ols), .(
    Model = gsub("_", " ", outcome),
    DML = theta_dml,
    DML_SE = se_dml,
    OLS = theta_ols,
    OLS_SE = se_ols
  )]
  
  if (nrow(df) == 0) return(NULL)
  
  df_long <- rbind(
    data.table(Model = df$Model, Estimate = df$DML, SE = df$DML_SE, Method = "DoubleML"),
    data.table(Model = df$Model, Estimate = df$OLS, SE = df$OLS_SE, Method = "OLS (key controls)")
  )
  
  pd <- position_dodge(width = 0.4)
  
  p <- ggplot(df_long, aes(x = Model, y = Estimate, color = Method, group = Method)) +
    geom_point(position = pd, size = 3) +
    geom_errorbar(aes(ymin = Estimate - 1.96 * SE, ymax = Estimate + 1.96 * SE),
                  position = pd, width = 0.2) +
    geom_hline(yintercept = 0, linetype = "dashed", color = "gray50") +
    scale_color_manual(values = c("DoubleML" = "#2980b9", "OLS (key controls)" = "#c0392b")) +
    coord_flip() +
    labs(
      title = "DoubleML vs OLS: Point Estimates with 95% CI",
      x = NULL,
      y = "ATE"
    ) +
    theme_minimal(base_size = 12) +
    theme(
      plot.title = element_text(face = "bold"),
      legend.position = "bottom"
    )
  
  return(p)
}

# ==============================================================================
# MAIN PLOT GENERATION
# ==============================================================================

cat("========================================\n")
cat("SENSITIVITY PLOTS\n")
cat("========================================\n\n")

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

cat("Loading existing sensitivity results...\n")

all_results <- tryCatch(
  readRDS(file.path(OUTPUT_DIR, "sensitivity_analysis.rds")),
  error = function(e) NULL
)

if (is.null(all_results)) {
  cat("No saved sensitivity results found. Re-running sensitivity analysis...\n")
  source(here::here("code", "run_sensitivity.R"))
  all_results <- readRDS(file.path(OUTPUT_DIR, "sensitivity_analysis.rds"))
}

# ==============================================================================
# FIGURE 1: Influence Function Distributions
# ==============================================================================

cat("\n--- Plot 1: Influence Function Distributions ---\n")

if_plots <- list()
for (m in models_to_analyze) {
  cat(sprintf("  Processing: %s\n", m$desc))
  if_obj <- load_checkpoint(file.path(CHECKPOINT_DIR, m$file))
  p <- plot_if_distribution(if_obj)
  if_plots[[m$desc]] <- p
  
  # Save individual
  fname <- file.path(FIGURE_DIR, sprintf("if_dist_%s.png", if_obj$outcome))
  ggsave(fname, p, width = 8, height = 5, dpi = 200)
  cat(sprintf("  Saved: %s\n", fname))
}

# Combined panel
cat("  Creating combined panel...\n")
combined_if <- arrangeGrob(grobs = if_plots, ncol = 1)
ggsave(file.path(FIGURE_DIR, "if_distributions_panel.png"),
       combined_if, width = 9, height = 14, dpi = 200)
cat("  Saved: Figures/if_distributions_panel.png\n")

# ==============================================================================
# FIGURE 2: RV Comparison Bar Chart
# ==============================================================================

cat("\n--- Plot 2: RV Comparison ---\n")

p_rv <- plot_rv_comparison(all_results)
ggsave(file.path(FIGURE_DIR, "rv_comparison.png"), p_rv, width = 8, height = 5, dpi = 200)
cat("  Saved: Figures/rv_comparison.png\n")

# ==============================================================================
# FIGURE 3: OLS vs DML Comparison
# ==============================================================================

cat("\n--- Plot 3: OLS vs DML Comparison ---\n")

p_compare <- plot_ols_dml_comparison(all_results)
if (!is.null(p_compare)) {
  ggsave(file.path(FIGURE_DIR, "ols_dml_comparison.png"), p_compare, width = 8, height = 5, dpi = 200)
  cat("  Saved: Figures/ols_dml_comparison.png\n")
} else {
  cat("  (No OLS comparison data available)\n")
}

# ==============================================================================
# FIGURE 4: Sensemakr Contour Plots (for benchmark comparisons)
# ==============================================================================

cat("\n--- Plot 4: Sensemakr Contour Plots ---\n")

for (m in models_to_analyze) {
  cat(sprintf("  Processing: %s\n", m$desc))
  
  cp <- readRDS(file.path(CHECKPOINT_DIR, m$file))
  dml <- cp$model
  dat <- dml$data$data
  
  # Select key confounders for OLS + sensemakr
  key_vars <- c("wealth_q1", "wealth_q2", "wealth_q3", "wealth_q4",
                "edu_0", "edu_1", "edu_2", "edu_3",
                "urban_bin", "sanitation", "num_children")
  if ("log_WQ27" %in% colnames(dat)) {
    key_vars <- c(key_vars, "log_WQ27")
  }
  key_vars <- key_vars[key_vars %in% colnames(dat)]
  
  # OLS with key confounders
  cols_needed <- c("y", "d", key_vars)
  cols_avail <- cols_needed[cols_needed %in% colnames(dat)]
  if (length(cols_avail) < 3) {
    cat("    (insufficient columns for sensemakr contour)\n")
    next
  }
  ols_df <- as.data.frame(dat[, ..cols_avail])
  ols_df <- ols_df[complete.cases(ols_df), , drop = FALSE]
  
  if (is.null(ols_df) || nrow(ols_df) < 100 || ncol(ols_df) < 3) {
    cat("    (insufficient data for sensemakr contour)\n")
    next
  }
  
  # Remove zero-variance columns
  X_mat <- as.matrix(ols_df[, -c(1, 2), drop = FALSE])
  var_check <- apply(X_mat, 2, var, na.rm = TRUE)
  X_mat <- X_mat[, var_check > 1e-10, drop = FALSE]
  
  if (ncol(X_mat) < 1) {
    cat("    (no valid covariates for OLS)\n")
    next
  }
  
  ols_clean <- cbind(y = ols_df$y, d = ols_df$d, as.data.frame(X_mat))
  formula_str <- paste("y ~ d +", paste(colnames(ols_clean)[-(1:2)], collapse = " + "))
  
  model_ols <- tryCatch(lm(as.formula(formula_str), data = ols_clean),
                         error = function(e) NULL)
  
  if (is.null(model_ols)) {
    cat("    (OLS model failed)\n")
    next
  }
  
  # Benchmark covariates available in this model
  bench_avail <- m$benchmark[m$benchmark %in% colnames(ols_clean)]
  if (length(bench_avail) == 0) {
    cat("    (no benchmark covariates available)\n")
    next
  }
  
  # Run sensemakr
  sense <- tryCatch(sensemakr(
    model = model_ols,
    treatment = "d",
    benchmark_covariates = bench_avail,
    kd = c(0.5, 1, 2),
    ky = c(0.5, 1, 2)
  ), error = function(e) NULL)
  
  if (is.null(sense)) {
    cat("    (sensemakr failed)\n")
    next
  }
  
  # Save contour plot
  fname_contour <- file.path(FIGURE_DIR, sprintf("contour_%s.png", cp$outcome))
  tryCatch({
    png(fname_contour, width = 8, height = 6, units = "in", res = 200)
    par(mar = c(5, 5, 4, 2))
    plot(sense, type = "contour",
         cex.lab = 0.9, cex.axis = 0.8, cex.main = 0.9,
         main = sprintf("Sensitivity Contour: %s → %s", cp$treatment, cp$outcome))
    dev.off()
    cat(sprintf("  Saved: %s\n", fname_contour))
  }, error = function(e) {
    cat(sprintf("    Contour plot failed: %s\n", e$message))
    dev.off()
  })
}

# ==============================================================================
# COMBINED REPORT
# ==============================================================================

cat("\n\n")
cat("========================================\n")
cat("ALL PLOTS GENERATED\n")
cat("========================================\n")
cat(sprintf("Figures saved to: %s\n", FIGURE_DIR))
cat(sprintf("\nFiles created:\n"))
for (f in list.files(FIGURE_DIR, pattern = "\\.png$")) {
  cat(sprintf("  %s\n", f))
}

cat("\n=== SENSITIVITY PLOTS COMPLETE ===\n")
