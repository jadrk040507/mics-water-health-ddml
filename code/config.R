# ==============================================================================
# MICS DoubleML - Configuration
# ==============================================================================

# Project paths (relative to project root)
DATA_FILE <- here::here("data", "MASTER_MICS_DDML_FINAL.dta")
OUTPUT_DIR <- here::here("Output")
CHECKPOINT_DIR <- here::here("Output", "checkpoints")

# Create directories
dir.create(OUTPUT_DIR, showWarnings = FALSE, recursive = TRUE)
dir.create(CHECKPOINT_DIR, showWarnings = FALSE, recursive = TRUE)

# Random seed
set.seed(42)

# ==============================================================================
# LEARNERS
# ==============================================================================

# Base learners for DoubleML
LEARNER_NAMES <- c("ols", "lasso", "ridge", "enet", "rf", "xgb")

# ==============================================================================
# OUTCOMES
# ==============================================================================

# Binary outcome (diarrhea only)
BINARY_OUTCOMES <- list(
  list(var = "diarrhea", label = "Diarrhea", desc = "Child diarrhea (2-week recall)")
)

# Continuous outcome (log-transformed E.coli)
CONTINUOUS_OUTCOMES <- list(
  list(var = "log_WQ26", label = "log_Ecoli", desc = "log(1 + E.coli count) at home")
)

# E.coli risk outcomes (binary)
ECOLI_RISK_OUTCOMES <- list(
  list(var = "some_risk_home", label = "SomeRiskHome", desc = "Any E.coli risk at home"),
  list(var = "very_high_risk_home", label = "VeryHighRiskHome", desc = "Very high E.coli risk (>100 CFU)")
)

# ==============================================================================
# TREATMENTS
# ==============================================================================

# Any treatment (binary) - includes boil, chlorine, filter, other
ANY_TREATMENT <- list(var = "any_treatment", label = "Any")

# Specific treatments (vs control)
MULTI_TREATMENTS <- list(
  list(var = "boil", label = "Boil"),
  list(var = "chlorine", label = "Chlorine"),
  list(var = "filter", label = "Filter"),
  list(var = "other_treat", label = "Other")
)

# ==============================================================================
# CONFOUNDERS
# ==============================================================================

# Base confounders (common to all models)
BASE_CONFOUNDERS <- c(
  # Wealth (quintile dummies)
  "wealth_q1", "wealth_q2", "wealth_q3", "wealth_q4", "wealth_q5",
  # Education (dummies)
  "edu_0", "edu_1", "edu_2", "edu_3", "edu_4", "edu_na",
  # Urban
  "urban_bin",
  # Sanitation
  "sanitation",
  # Household composition
  "num_children",
  # Water source (will create dummies)
  "water_source"
)

# Country fixed effects (create dummies later)
COUNTRY_FE <- "country"

# Source E.coli (for diarrhea model only)
SOURCE_ECOLI <- "log_WQ27"

# ==============================================================================
# SUBGROUPS
# ==============================================================================

SUBGROUP_VAR <- "RiskSource"
SUBGROUP_LABELS <- c("No Risk" = 0, "Moderate" = 1, "High" = 2)

# ==============================================================================
# CROSS-VALIDATION
# ==============================================================================

N_FOLDS <- 5
N_REP <- 2