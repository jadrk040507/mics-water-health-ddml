# MICS Water, Health & Double ML 💧

> **Causal effects of household water treatment on E. coli contamination and child diarrhea using Double/Debiased Machine Learning**
>
> 📊 59,620 households · 25 countries · With Prof. Akito Kamei (University of Chicago)

[![R](https://img.shields.io/badge/R-4.x-276DC3?logo=r)](https://www.r-project.org/)
[![Stata](https://img.shields.io/badge/Stata-18-306998)](https://www.stata.com/)
[![DoubleML](https://img.shields.io/badge/DoubleML-IRM-success)](https://docs.doubleml.org/)
[![Status](https://img.shields.io/badge/status-in%20progress-yellow)](#)
[![Paper](https://img.shields.io/badge/paper-in%20preparation-blue)](#)

---

## 🎯 Overview

This project estimates the causal effect of household water treatment (boiling, chlorination, filtration) on E. coli contamination and child diarrhea using **Double/Debiased Machine Learning (DDML)** with the Interactive Regression Model (IRM) specification.

**Key finding:** Boiling water reduces E. coli high risk by **14.2 pp (46%)** and child diarrhea by **4.5 pp (25%)**. Effects are **3-4x larger** in highly contaminated water sources — treatment is most effective where it's needed most.

---

## 🧪 Methodology

### Causal Framework

```
Source E. coli → Treatment Decision → Household E. coli → Child Health
       │                │                                         │
       └──────── Confounders (wealth, education, location) ────────┘
```

### DDML-IRM Specification

- **Outcome model**: `g(T, X)` — ML-based prediction of E. coli / diarrhea
- **Propensity model**: `m(X)` — ML-based prediction of treatment
- **Neyman-orthogonal score** debiases regularization bias
- **5-fold cross-fitting** (2 repetitions) prevents overfitting

### 7 Learners Implemented

| Learner | Role |
|---------|------|
| OLS | Linear baseline |
| Lasso (CV-tuned α) | L1 regularization |
| Ridge (CV-tuned α) | L2 regularization |
| Elastic Net (α=0.5) | Combined L1/L2 |
| Random Forest (500 trees) | Non-linearities |
| XGBoost (300 rounds) | Gradient boosting |
| Stacked Ensemble | Ridge meta-learner on OOF predictions |

### Identification Assumptions

- **CIA**: Treatment as-if random conditional on confounders + source E. coli
- **Overlap**: Empirically verified — all treatment cells have support
- **SUTVA**: No spillovers between households (plausible at household level)
- **Convergence validation**: PLM vs IRM estimates converge within 0.003

---

## 📂 Project Structure

```
├── MICS_ANALISIS_CAUSAL.md     ← Full empirical framework + meta-analysis
├── code/
│   ├── config.R                ← Configuration & paths
│   ├── data.R                  ← Data loading & preparation
│   ├── learners.R              ← ML learner definitions
│   ├── models.R                ← DoubleML estimation pipeline
│   ├── run.R                   ← Main ATE estimation
│   ├── run_cate_extended.R     ← CATE via influence functions
│   ├── run_sensitivity.R       ← Robustness Values + diagnostics
│   ├── export_tables.R         ← LaTeX table generation
│   └── 1_Cleaning.do           ← Stata data cleaning
├── docs/
│   ├── MODEL_SPECIFICATION.md  ← Detailed model documentation
│   └── VARIABLES.md            ← Variable dictionary
├── Output/                     ← Results (.rds) + LaTeX tables
├── Figure/                     ← Coefficient plots + maps
├── Table/                      ← Descriptive + robustness tables
├── Citation_Water.bib          ← BibTeX references
└── main.tex                    ← Paper draft source
```

---

## 🚀 Quick Start

```r
# Open MICS_PROJECT.Rproj in RStudio
source("code/config.R")
source("code/run.R")                         # Main ATE estimation
source("code/run_cate_extended.R")           # CATE by subgroup
source("code/run_sensitivity.R")             # Robustness analysis
source("code/export_tables.R")               # Generate LaTeX tables
```

---

## 📊 Key Results

### Average Treatment Effects

| Outcome | Treatment | ATE | SE | 95% CI |
|---------|-----------|-----|-----|--------|
| E. coli high risk | Any | −0.086*** | 0.005 | [−0.097, −0.076] |
| E. coli high risk | **Boil** | **−0.142*** | 0.012 | [−0.165, −0.118] |
| Diarrhea | **Boil** | **−0.045*** | 0.009 | [−0.062, −0.027] |
| Diarrhea | Chlorine | NS | — | — |

### Heterogeneity by Source Risk

| Source Risk | E. coli High Risk ATE | Interpretation |
|-------------|----------------------|----------------|
| No risk (0 CFU) | −0.006 (NS) | No effect where source is clean |
| Moderate (1–100) | −0.043*** | Moderate benefit |
| **Very high (>100)** | **−0.219*** | **71% reduction from baseline** |

### Meta-Analysis Comparison

| Study | Method | Effect on Diarrhea |
|-------|--------|--------------------|
| **Clasen et al. (2007)** | Meta-RCT | −29% |
| **WASH Benefits (2018)** | RCT | NS |
| **This study** | DDML obs. | **−25% (boiling)** |

---

## ⚠️ Limitations

- **Unobserved confounding** cannot be ruled out in observational data — results should be interpreted as lower bounds
- **Measurement error**: E. coli measured at one point in time; diarrhea is 2-week recall
- **Re-contamination**: Boiled water may be re-contaminated via storage
- **External validity**: Sample covers MICS-participating countries; results may not generalize to all contexts

---

## 📚 References

- Chernozhukov et al. (2018). *Double/debiased machine learning for treatment and structural parameters.* Econometrics Journal.
- Bach et al. (2022). *DoubleML: An Object-Oriented Implementation of Double Machine Learning in R.* JMLR.
- Cinelli & Hazlett (2020). *Making Sense of Sensitivity.* JRSS-B.
- Clasen et al. (2007). *Interventions to improve water quality for preventing diarrhoea.* Cochrane Review.

---

## 👤 Author

**Juan Alvaro Díaz Raimond Kedilhac**
- 🎓 B.Sc. Economics, Universidad Panamericana (GPA 98/100, top of class)
- 📧 jadrk040507@gmail.com
- 🔗 [LinkedIn](https://www.linkedin.com/in/jadrk040507/)
- 🔗 [GitHub](https://github.com/jadrk040507)

*Collaboration with Prof. Akito Kamei, University of Chicago*
