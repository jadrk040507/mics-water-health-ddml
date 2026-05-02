---
editor_options: 
  markdown: 
    wrap: 72
---

# Model Specification - DoubleML Analysis

## Research Question

**What is the causal effect of household water treatment on:** 1. Child
diarrhea (binary outcome) 2. E. coli contamination at home (binary and
continuous outcomes)

------------------------------------------------------------------------

## Causal Framework

```         
                        ┌─────────────────┐
                        │   Treatment     │
                        │  (Boil/Cloro/   │
                        │   Filter)       │
                        └────────┬────────┘
                                 │
                                 ▼
┌─────────────┐          ┌──────────────┐          ┌─────────────┐
│  Source     │          │   Home       │          │  Diarrhea   │
│  E.coli     │──────────│   E.coli     │──────────│  (Outcome)  │
│  (WQ27)     │          │   (WQ26)      │          │             │
└─────────────┘          └──────────────┘          └─────────────┘
      ▲                        │                        ▲
      │                        │                        │
      │                        ▼                        │
      │                 ┌─────────────┐                 │
      │                 │  Treatment  │─────────────────┘
      │                 │  Decision    │
      │                 └─────────────┘
      │                        ▲
      │                        │
      └────────────────────────┘
           (Confounder)
```

**Key insight:** Source E.coli (WQ27) affects treatment decision AND
home E.coli, but home E.coli is NOT a confounder for diarrhea (it's a
mediator).

------------------------------------------------------------------------

## Model 1: Diarrhea (Total Effect)

### Outcome

-   `diarrhea`: Binary (child had diarrhea in last 2 weeks)

### Treatment

-   **Any treatment**: `any_treatment` (binary)
-   **Specific**: `boil`, `chlorine`, `filter` (vs control)

### Confounders (X)

| Category          | Variables                       | Type       | N vars |
|-------------------|---------------------------------|------------|--------|
| **Wealth**        | `wealth_q1` - `wealth_q5`       | Dummies    | 5      |
| **Education**     | `edu_0` - `edu_4`, `edu_na`     | Dummies    | 6      |
| **Urban**         | `urban_bin`                     | Binary     | 1      |
| **Sanitation**    | `sanitation` (improved latrine) | Binary     | 1      |
| **Household**     | `num_children`                  | Continuous | 1      |
| **Water Source**  | `ws_*` (15 categories)          | Dummies    | \~15   |
| **Country**       | `ctry_*` (32 countries)         | Dummies    | \~32   |
| **Source E.coli** | `log_WQ27`                      | Continuous | 1      |

**Total confounders: \~61 variables**

### Model

``` r
# DoubleML IRM (binary treatment, binary outcome)
dml <- DoubleMLIRM$new(
  data = dml_data,
  ml_g = learner_g,  # outcome model
  ml_m = learner_m,  # propensity model
  n_folds = 5,
  n_rep = 2,
  score = "ATE"
)
```

**Equation:** $$\tau = E[Y(1) - Y(0)]$$

Where Y(1) is potential outcome with treatment, Y(0) without.

------------------------------------------------------------------------

## Model 2: E. coli (Mechanism)

### Outcome

-   **Binary**: `ecoli_high` (E.coli \> 100 CFU/100mL at home)
-   **Continuous**: `log_WQ26` (log(1 + E.coli count))

### Treatment

-   Same as diarrhea model

### Confounders (X)

| Category         | Variables                   | Type       | N vars |
|------------------|-----------------------------|------------|--------|
| **Wealth**       | `wealth_q1` - `wealth_q5`   | Dummies    | 5      |
| **Education**    | `edu_0` - `edu_4`, `edu_na` | Dummies    | 6      |
| **Urban**        | `urban_bin`                 | Binary     | 1      |
| **Sanitation**   | `sanitation`                | Binary     | 1      |
| **Household**    | `num_children`              | Continuous | 1      |
| **Water Source** | `ws_*`                      | Dummies    | \~15   |
| **Country**      | `ctry_*`                    | Dummies    | \~32   |

**Total confounders: \~60 variables**

**⚠️ DO NOT INCLUDE:** `log_WQ27` (source E.coli) because: - Source
E.coli is BEFORE treatment decision - Home E.coli is AFTER treatment -
Including source E.coli would BLOCK the causal pathway

------------------------------------------------------------------------

## Model 3: Subgroups by Source Risk

Stratify by `RiskSource` (source E.coli level):

| Level | Description | E.coli at Source | N      | \%    |
|-------|-------------|------------------|--------|-------|
| 0     | No risk     | 0 CFU/100mL      | 25,511 | 42.8% |
| 1     | Moderate    | 1-100 CFU/100mL  | 21,841 | 36.6% |
| 2     | High        | \>100 CFU/100mL  | 12,268 | 20.6% |

**Hypothesis:** Treatment effects are larger in high-risk sources.

------------------------------------------------------------------------

## ML Learners

### Base Learners

| Learner | Description             | Hyperparameters              |
|---------|-------------------------|------------------------------|
| `ols`   | Linear regression       | None                         |
| `lasso` | Lasso (cv_glmnet)       | alpha = 1                    |
| `ridge` | Ridge (cv_glmnet)       | alpha = 0                    |
| `enet`  | Elastic Net (cv_glmnet) | alpha = 0.5                  |
| `rf`    | Random Forest (ranger)  | 500 trees                    |
| `xgb`   | XGBoost                 | 300 rounds, depth=4, eta=0.1 |

### Stacked Ensemble

```         
Stacked Ensemble:
├── Base learners:
│   ├── Elastic Net (alpha=0.5)
│   ├── Random Forest (300 trees)
│   └── XGBoost (200 rounds)
└── Meta-learner: Ridge (alpha=0)
```

------------------------------------------------------------------------

## Cross-Validation

-   **N folds:** 5
-   **N repetitions:** 2
-   **Score:** ATE (Average Treatment Effect)

------------------------------------------------------------------------

## Sample Sizes

| Analysis        | Outcome     | Treatment           | N        |
|-----------------|-------------|---------------------|----------|
| Any Treatment   | Diarrhea    | Any vs None         | 25,202   |
| Any Treatment   | E.coli High | Any vs None         | 59,620   |
| Multi Treatment | Diarrhea    | Boil vs Control     | \~21,000 |
| Multi Treatment | Diarrhea    | Chlorine vs Control | \~19,000 |
| Multi Treatment | Diarrhea    | Filter vs Control   | \~20,000 |
| Multi Treatment | E.coli      | Boil vs Control     | \~52,000 |
| Multi Treatment | E.coli      | Chlorine vs Control | \~45,000 |
| Multi Treatment | E.coli      | Filter vs Control   | \~48,000 |

------------------------------------------------------------------------

## Expected Outcomes

Based on prior analysis:

### Any Treatment Effect

| Outcome     | Effect | SE    | 95% CI           |
|-------------|--------|-------|------------------|
| Diarrhea    | -0.018 | 0.007 | [-0.032, -0.004] |
| E.coli High | -0.066 | 0.005 | [-0.076, -0.056] |

### Boil vs Control

| Outcome     | Effect | SE    | 95% CI           |
|-------------|--------|-------|------------------|
| Diarrhea    | -0.046 | 0.009 | [-0.064, -0.028] |
| E.coli High | -0.142 | 0.012 | [-0.166, -0.118] |

### Subgroup Effects (Boil)

| Source Risk | Diarrhea Effect |
|-------------|-----------------|
| No risk     | -6.5 pp         |
| Moderate    | -13.8 pp        |
| High        | **-26.2 pp**    |

------------------------------------------------------------------------

## Files Structure

```         
MICS_PROJECT/
├── code/
│   ├── config.R      # Configuration
│   ├── data.R        # Data preparation
│   ├── learners.R    # ML learners
│   ├── models.R      # DoubleML estimation
│   └── run.R         # Main script
├── Output/
│   ├── checkpoints/  # Model checkpoints (.rds)
│   ├── results_*.rds  # Results
│   └── tables.tex     # LaTeX tables
└── docs/
    └── VARIABLES.md   # Variable documentation
```

------------------------------------------------------------------------

## To Run

``` r
# In RStudio, open MICS_PROJECT.Rproj
# Then:
source("code/config.R")
source("code/run.R")
```

This will: 1. Load and prepare data 2. Run 7 learners × 3 analyses × 2
outcomes 3. Save checkpoints for resumption 4. Export results to RDS and
LaTeX
