---
editor_options: 
  markdown: 
    wrap: 72
---

# Complete Model Specification — MICS Water Quality DoubleML Analysis

## Research Question

**What is the causal effect of household water treatment on E. coli
contamination and child diarrhea, and how much of the health effect is
mediated through water quality improvement?**

------------------------------------------------------------------------

## Part 1: Causal Framework

### The Behavioral/Targeting Chain (Scenario B)

In observational data (non-experimental), households are active
decision-makers. The causal structure is:

```         
M_source (E. coli at source) → T (Treatment decision) → M_drinking (E. coli at home) → Y (Health outcome)
         ↑                                                                              ↑
         └──────────────────────── X (Confounders) ──────────────────────────────────────┘
```

**Key Insight:** Households with contaminated source water are MORE
LIKELY to treat their water. This creates **selection bias** if not
properly controlled.

------------------------------------------------------------------------

## Part 2: Variable Mapping — IPUMS MICS

### Household-Level Analysis

| Role | Parameter | IPUMS MICS Variable | Description |
|----|----|----|----|
| **Outcome (Y)** | Child Health | `DIARRHEA` | Binary: Diarrhea in last 2 weeks |
| **Treatment (T)** | Water Treatment | `wtrtreat` | Composite (see below) |
| **Source Context** | `M_source` | `wqecolisource` | E. coli CFU at source |
| **Source Context** | `M_source` | `wtrdrink` | Water source type |
| **Mediator** | `M_drinking` | `wqecolisample` | E. coli CFU at point-of-use |
| **Controls** | Wealth | `windex5` | Wealth quintile |
| **Controls** | Education | `edlevelmom` | Mother's education level |
| **Controls** | Location | `urban` | Urban/rural |
| **Controls** | Household | `hhsize`, `numch` | Household size, \# children |
| **Weights** | Survey weight | `weighthh` | Household weight |

### Children Under 5 Analysis

| Role | Parameter | IPUMS MICS Variable | Description |
|----|----|----|----|
| **Outcome (Y)** | Child Diarrhea | `diarr` | Binary: Diarrhea in last 2 weeks |
| **Treatment (T)** | Water Treatment | Composite of `wtrboil`, `wtrbleach`, etc. | Any effective treatment |
| **Source Context** | `M_source` | `wqecolisource` | E. coli CFU at source |
| **Mediator** | `M_drinking` | `wqecolisample` | E. coli CFU at point-of-use |
| **Child Controls** | Age, Sex | `agech`, `sexch` | Child age (months), sex |
| **Child Controls** | Mother's Ed | `edlevelmom` | Mother's education |
| **HH Controls** | Wealth | `windex5` | Wealth quintile |
| **HH Controls** | Location | `urban` | Urban/rural |
| **HH Controls** | Household | `hhsize`, `numch` | Household size, \# children |
| **Asset Controls** | High-dim SES | `electricity`, `radio`, `television`, `mobile`, `car`, `fridge` | Asset indicators |
| **Weights** | Survey weight | `weightch` | **Child-level weight** |

### Treatment Variable Construction

**Composite Treatment (T)** — More robust than single indicator:

``` r
# Create composite treatment: 1 if any EFFECTIVE method used
child_data$T <- ifelse(
  child_data$wtrboil == 1 |
  child_data$wtrbleach == 1 |
  child_data$wtrfilter == 1 |
  child_data$wtrsolar == 1,
  1, 0
)
```

**Why composite?** Ensures "ineffective" treatments (like just letting
water stand) don't dilute the estimated effect.

### Recoding Requirements

| Transformation | Variable | Method |
|----|----|----|
| Binary recoding | `diarr`, `wtrtreat` | Convert 1=Yes, 2=No → 1, 0 |
| Log transformation | `wqecolisource`, `wqecolisample` | `log10(CFU + 1)` |
| One-hot encoding | `wtrdrink`, `toilettype`, `floor`, `roof`, `walls` | Dummy variables |
| Missing handling | All variables | Convert 9, 99, 999 → NA |

------------------------------------------------------------------------

## Part 3: Survey Weight Handling

### Critical Rule: Match Weight to Analysis Level

| Analysis Level  | Weight Variable | Why                             |
|-----------------|-----------------|---------------------------------|
| Household-level | `weighthh`      | Accounts for HH non-response    |
| Child-level     | `weightch`      | Accounts for child non-response |
| Women-level     | `weightwm`      | Accounts for women non-response |

**Why it matters:** Child-level analysis uses `weightch` because it
accounts for: - Household selection probability - Child-level
non-response - Child mortality (deceased children not surveyed)

------------------------------------------------------------------------

## Part 4: Three Key Effects

### Effect Definitions

1.  **Total Effect (TE):** Overall impact of treatment on outcome

    ```         
    TE = E[Y(1, M(1)) - Y(0, M(0))]
    ```

2.  **Natural Direct Effect (NDE):** Effect NOT through E. coli

    ```         
    NDE = E[Y(1, M(0)) - Y(0, M(0))]
    ```

3.  **Natural Indirect Effect (NIE):** Effect THROUGH E. coli reduction

    ```         
    NIE = E[Y(1, M(1)) - Y(1, M(0))] = θ_Total - θ_Direct
    ```

### Interpretation Guide

| Scenario | Interpretation |
|----|----|
| DE ≈ 0, TE significant | E. coli reduction is PRIMARY mechanism |
| DE large, TE significant | Treatment works through MULTIPLE pathways |
| IE small, TE large | Non-microbial benefits (hygiene, other pathogens) |
| TE ≈ 0 | No overall treatment effect |

### Calculating Proportion Mediated

```         
Proportion_Mediated = (θ_Total - θ_Direct) / θ_Total
```

------------------------------------------------------------------------

## Part 5: Why E. coli is a Mediator (Not a Control)

### The "Blocked Path" Problem

**Critical Rule:** To estimate the **Total Effect**, you MUST NOT
include E. coli at home in the regression.

| Goal | Include M_drinking? | Why |
|----|----|----|
| Estimate Total Effect | **NO** | Would block the treatment pathway |
| Estimate Direct Effect | **YES** | Isolates effect not through E. coli |
| Mechanism validation | **YES** (separate model) | Confirms intervention worked |

### The "Bad Control" Warning

Including `wqecolisample` (POU E. coli) when estimating Total Effect
creates **post-treatment bias**:

-   You are "holding water quality constant"
-   This hides the very mechanism through which treatment works
-   Results in UNDERESTIMATE of true effect

------------------------------------------------------------------------

## Part 6: The Re-contamination Problem

### Source vs. Drinking Water

| Location | Variable | Role | Why It Matters |
|----|----|----|----|
| Source (POC) | `wqecolisource` | **Confounder** | Influences treatment decision |
| Drinking (POU) | `wqecolisample` | **Mediator/Outcome** | What treatment actually changes |

**Key Finding:** Studies show E. coli can be HIGHER at point-of-use than
at source due to: - Dirty storage containers - Unwashed hands - Lack of
residual chlorine - Long storage duration

This is the **"Leaky Pipe"** problem: improving source quality is futile
if re-contamination occurs during transport/storage.

------------------------------------------------------------------------

## Part 7: Complete R Implementation

### Children Under 5 Analysis

``` r
# ==============================================================================
# DoubleML Analysis — MICS Water Treatment Effect on Child Diarrhea
# ==============================================================================

library(DoubleML)
library(mlr3)
library(mlr3learners)
library(data.table)

# --- 1. Data Preparation -----------------------------------------------------

# Recode Outcome: IPUMS uses 1=Yes, 2=No → convert to 1, 0
child_data$diarr_bin <- ifelse(child_data$diarr == 1, 1, 0)

# Create Composite Treatment (T)
# 1 if any effective method used, 0 otherwise
child_data$T <- ifelse(
  child_data$wtrboil == 1 |
  child_data$wtrbleach == 1 |
  child_data$wtrfilter == 1 |
  child_data$wtrsolar == 1,
  1, 0
)

# Log-transform Microbial Indicators (handle skewness and zeros)
child_data$log_ecoli_src <- log10(child_data$wqecolisource + 1)
child_data$log_ecoli_pou <- log10(child_data$wqecolisample + 1)

# Define Control Sets
child_controls <- c("agech", "sexch", "edlevelmom")
hh_controls <- c("windex5", "urban", "hhsize", "numch", "log_ecoli_src")
asset_controls <- c("electricity", "radio", "television", "mobile", "car", "fridge")

X_cols <- c(child_controls, hh_controls, asset_controls)

# --- 2. Define Learners ------------------------------------------------------

# Random Forest handles non-linearities in child age and asset interactions
l_rate <- lrn("regr.ranger", num.trees = 500)
l_prob <- lrn("classif.ranger", num.trees = 500)

# --- 3. Estimate Total Effect (TE) -------------------------------------------

# Do NOT include mediator (log_ecoli_pou) — we want the full pathway
dml_data_te <- DoubleMLData$new(
  child_data,
  y_col    = "diarr_bin",
  d_cols   = "T",
  x_cols   = X_cols,
  weights  = "weightch"  # Child-level weight!
)

dml_plr_te <- DoubleMLPLR$new(dml_data_te, ml_l = l_rate, ml_m = l_prob)
dml_plr_te$fit()
te_coeff <- dml_plr_te$coef

# --- 4. Estimate Direct Effect (DE) ------------------------------------------

# Add the mediator (POU E. coli) to BLOCK the microbial pathway
X_cols_de <- c(X_cols, "log_ecoli_pou")

dml_data_de <- DoubleMLData$new(
  child_data,
  y_col    = "diarr_bin",
  d_cols   = "T",
  x_cols   = X_cols_de,
  weights  = "weightch"
)

dml_plr_de <- DoubleMLPLR$new(dml_data_de, ml_l = l_rate, ml_m = l_prob)
dml_plr_de$fit()
de_coeff <- dml_plr_de$coef

# --- 5. Calculate Indirect Effect (IE) ---------------------------------------

# Indirect Effect = Total - Direct (the microbial pathway)
ie_coeff <- te_coeff - de_coeff

# Proportion Mediated
prop_mediated <- ie_coeff / te_coeff

# --- 6. Display Results ------------------------------------------------------

cat("=== Causal Effect Decomposition ===\n")
cat(sprintf("Total Effect:           %.4f\n", te_coeff))
cat(sprintf("Direct Effect:          %.4f\n", de_coeff))
cat(sprintf("Indirect Effect:        %.4f\n", ie_coeff))
cat(sprintf("Proportion Mediated:    %.1f%%\n", prop_mediated * 100))
cat("\n--- Summary Tables ---\n")
print(dml_plr_te$summary())
print(dml_plr_de$summary())
```

------------------------------------------------------------------------

## Part 8: High-Dimensional Asset Controls

### Why Include Many Assets?

In traditional OLS, adding 20+ asset dummies causes: - Over-fitting -
Multicollinearity

**In DML, this is an ADVANTAGE:**

-   ML learners (Random Forest, XGBoost) thrive on high-dimensional data
-   They automatically determine which assets predict treatment/outcome
-   "Thick description" of household SES → better confounding control

### Recommended Asset Variables

``` r
asset_controls <- c(
  # Infrastructure
  "electricity", "bankacct",
  # Appliances
  "radio", "television", "fridge", "computer", "internet",
  # Transportation
  "bicycle", "motorcycle", "car", "cart",
  # Housing quality
  "floor", "roof", "walls",
  # Communication
  "mobile", "landline"
)
```

------------------------------------------------------------------------

## Part 9: Data Merging

### Merging HH, CH, and WQ Modules

To link child-level analysis to water quality data:

``` r
# Merge steps:
# 1. HH module (household characteristics)
# 2. CH module (children under 5)
# 3. WQ module (water quality testing)

# Common identifiers:
# - cluster: PSU/cluster ID
# - hhno: Household number
# - linech: Child line number (within household)

# Example merge:
merged_data <- merge(hh_data, ch_data,
                     by = c("cluster", "hhno"),
                     all.y = TRUE)

merged_data <- merge(merged_data, wq_data,
                     by = c("cluster", "hhno", "linech"),
                     all.x = TRUE)
```

------------------------------------------------------------------------

## Part 10: Summary — The Complete Causal Story

```         
Household observes dirty source water (wqecolisource high)
         ↓
    Decides to treat (wtrtreat = 1)
         ↓
    Applies method (boil/chlorine/filter)
         ↓
    Drinking water quality changes (wqecolisample)
         ↓
    Child health affected (diarr)
```

**The econometric challenge:** Households with worse source water are
more likely to treat. Simple comparison shows "treaters have worse
outcomes" due to baseline differences.

**The DML solution:** Use ML to partial out confounding from source
water and household characteristics, isolating the causal effect.

------------------------------------------------------------------------

## Key Literature

1.  **Kremer et al. (2023):** Water treatment reduces child mortality by
    \~25%
2.  **Duflo et al. (2015):** Sanitation externalities — need
    community-wide coverage
3.  **Ahuja, Kremer, Zwane (2011):** WTP highly price-sensitive, case
    for subsidies
4.  **Burlig et al. (2025):** Information frictions in water quality
    valuation
5.  **Dupas et al. (2023):** Behavioral delivery mechanisms matter

------------------------------------------------------------------------

*Document generated from Hyperknow learning session: "WASH Development
Economics: Key Literature & Data"*
