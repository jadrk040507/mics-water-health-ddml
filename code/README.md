# MICS DoubleML — Code Directory

Core scripts for the DoubleML causal analysis of household water treatment on child diarrhea and E. coli contamination.

## Pipeline Overview

```         
config.R             →  data.R             →  run.R
                          (data prep)          (main estimation)
                          learners.R
                            ↓
                    run_cate_extended.R     (CATEs via influence functions)
                    run_sensitivity.R        (robustness values)
                    export_tables_cate_sensitivity.R  (LaTeX exporter)
                    extract_weights.R        (model weights for stacked ensemble)
```

## Scripts

| File | Purpose | Output |
|----|----|----|
| **config.R** | Paths, learners, outcomes, treatments, confounders — sourced by all scripts | — |
| **data.R** | Load, clean, and prepare MICS data (outcomes, treatments, confounders, subgroup vars) | `Data/MASTER_MICS_DDML_FINAL.dta` (read only) |
| **models.R** | DoubleML IRM fitting: any-treatment + 4 specific treatments × 3 outcomes | Checkpoints in `Output/checkpoints/` |
| **learners.R** | Define 6 base learners (OLS, Lasso, Ridge, Elastic Net, RF, XGBoost) + stacked ensemble | — |
| **run.R** | Orchestrates the full pipeline: data prep → model fitting for all (outcome × treatment) combos. Skips existing checkpoints (resumable). | `Output/results_*.rds`, `Output/tables.tex`, checkpoints |
| **run_cate_extended.R** | Influence function decomposition: computes CATEs by urban/rural, wealth quintile, and source E. coli risk **without re-estimation**. See note below. | `Output/results_cates_extended.rds` |
| **run_sensitivity.R** | Robustness Value (RV) analysis + OLS comparison + influence function diagnostics for key models (boil → diarrhea, boil → E. coli) | `Output/sensitivity_analysis.rds`, `Output/sensitivity_summary.csv` |
| **export_tables_cate_sensitivity.R** | Generates LaTeX tables from CATE and sensitivity output | `Table/*.tex` |
| **extract_weights.R** | Extracts stacked ensemble meta-learner weights | Console output |
| **1_Cleaning.do** | Stata cleaning script for original MICS data | — |

## CATE via Influence Functions (Key Method)

`run_cate_extended.R` uses the **influence function approach** (Chernozhukov et al.):

```         
CATE(g)  =  ATE  +  E[φᵢ | i ∈ subgroup g]
SE(g)    =  sd(φᵢ | i ∈ subgroup g) / √N_g
```

Where φᵢ are the influence functions from the already-fitted DoubleML IRM model. **No re-estimation needed** — all CATEs are derived from the same full-sample models.

## Subgroups Analyzed

-   **Urban/Rural** (`urban_bin`)
-   **Wealth quintile** (Q1–Q5, from dummies `wealth_q1`–`wealth_q5`)
-   **Source E. coli risk** (`RiskSource`: 0 = none, 1 = moderate, 2 = very high, from `src_no_risk`, `src_moderate`, `src_very_high`; available in diarrhea model only)

## Workflow

``` r
# Full pipeline (data → estimation → tables):
source("code/config.R")
source("code/run.R")
source("code/run_cate_extended.R")
source("code/run_sensitivity.R")
source("code/export_tables_cate_sensitivity.R")
```

## Dependencies

-   R ≥ 4.0, packages: `DoubleML`, `mlr3`, `mlr3learners`, `mlr3spatial`, `data.table`, `here`, `xtable`
-   External: `xgboost`, `ranger`, `glmnet`
