# MICS DoubleML - Variables Documentation

Generated: 2026-04-13 Dataset: MASTER_MICS_DDML_FINAL.dta (N = 59,620)

------------------------------------------------------------------------

## Outcomes

### Binary Outcome

| Variable   | Description                    | N      | Mean  | Type   |
|------------|--------------------------------|--------|-------|--------|
| `diarrhea` | Child diarrhea (2-week recall) | 25,202 | 0.177 | Binary |

### Continuous Outcome

| Variable   | Description                      | Mean | SD   | Min | Max  |
|------------|----------------------------------|------|------|-----|------|
| `log_WQ26` | log(1 + E.coli count) at home    | 2.57 | 1.91 | 0   | 4.62 |

**Note:** WQ26 = E.coli count at home (CFU/100mL). Values >100 are coded as 101 (right-censored). We use log(1+WQ26) for analysis.

------------------------------------------------------------------------

## Treatments

### Any Treatment (Binary)

| Variable        | Description                | N      | %      |
|-----------------|----------------------------|--------|--------|
| `any_treatment` | Any water treatment method | 12,671 | 21.3%  |

**Includes:** Boil + Chlorine + Filter + Other treatments

### Specific Treatments (vs Control)

| Variable     | Description        | N Treated | %    |
|--------------|--------------------|-----------|------|
| `boil`       | Boiling water      | 6,006     | 10.1% |
| `chlorine`   | Chlorine treatment | 1,296     | 2.2%  |
| `filter`     | Filtration         | 3,051     | 5.1%  |
| `other_treat`| Other treatment    | 2,316     | 3.9%  |

**Control group:** `no_treatment` (WQ15_g_0 = 1, N = 46,951, 78.8%)

**Note:** Treatments are mutually exclusive in WQ15_g. Each household reports ONE primary treatment method.

------------------------------------------------------------------------

## Confounders

### Wealth (Quintile Dummies)

| Variable    | Description      | \%    |
|-------------|------------------|-------|
| `wealth_q1` | Poorest quintile | 25.4% |
| `wealth_q2` | Second quintile  | 20.7% |
| `wealth_q3` | Middle quintile  | 19.3% |
| `wealth_q4` | Fourth quintile  | 18.1% |
| `wealth_q5` | Richest quintile | 16.5% |

Source: `windex5`

### Education (Household Head)

| Variable | Description     | \%    |
|----------|-----------------|-------|
| `edu_0`  | No education    | 25.1% |
| `edu_1`  | Primary         | 31.8% |
| `edu_2`  | Lower secondary | 25.3% |
| `edu_3`  | Upper secondary | 13.5% |
| `edu_4`  | College/higher  | 4.2%  |
| `edu_na` | Missing         | 0.1%  |

Source: `helevel`

### Demographics

| Variable       | Description        | Mean  | SD    |
|----------------|--------------------|-------|-------|
| `urban_bin`    | Urban residence    | 0.369 | 0.483 |
| `sanitation`   | Improved latrine   | 0.666 | 0.472 |
| `num_children` | Number of children | 2.1   | 1.5   |

### Water Source

| Variable | Description |
|----|----|
| `water_source` | Main source of drinking water (WS1) |
|  | 15 categories: piped, well, spring, rain, surface, purchased, etc. |

### Country Fixed Effects

| Variable  | Description                 |
|-----------|-----------------------------|
| `country` | Country name (32 countries) |

### Source E.coli (Confounder for Diarrhea Model)

| Variable   | Description                     | Mean | SD   | Min | Max  |
|------------|---------------------------------|------|------|-----|------|
| `log_WQ27` | log(1 + E.coli count) at source | 1.86 | 1.92 | 0   | 4.62 |
| `WQ27`     | E.coli count at source          | 28.6 | 40.9 | 0   | 101  |

**Critical:** Include `log_WQ27` in diarrhea model but NOT in E.coli model (treatment affects home E.coli directly).

------------------------------------------------------------------------

## Subgroups

### Source Risk Level

| Variable          | Description                | \%    |
|-------------------|----------------------------|-------|
| `risk_source = 0` | No E.coli at source        | 42.8% |
| `risk_source = 1` | Moderate (1-100 CFU/100mL) | 36.6% |
| `risk_source = 2` | High (\>100 CFU/100mL)     | 20.6% |

Source: `RiskSource`

------------------------------------------------------------------------

## Model Specification

### Diarrhea Model

```         
Outcome: diarrhea
Treatment: any_treatment, boil, chlorine, filter
Confounders:
  - wealth_q1-q5 (5 dummies)
  - edu_0-4, edu_na (6 dummies)
  - urban_bin
  - sanitation
  - num_children
  - water_source (15 dummies)
  - country (32 dummies)
  - log_WQ27 (source E.coli)
```

### E.coli Model (Mechanism)

```
Outcome: log_WQ26 (log(1 + E.coli count) at home)
Treatment: any_treatment, boil, chlorine, filter
Confounders:
  - wealth_q1-q5
  - edu_0-4, edu_na
  - urban_bin
  - sanitation
  - num_children
  - water_source
  - country
  (NO log_WQ27 - treatment affects home E.coli directly)
```

**Why log(1+WQ26)?**
1. Standard for count data with many zeros (26% have WQ26=0)
2. Interpretable: coefficient β ≈ percent change in E.coli
3. Reduces influence of extreme values (101 = >100)
4. Better distribution for ML models

------------------------------------------------------------------------

## Notes

1.  **Wealth OR Assets** (not both): Use windex5 quintiles
2.  **NO M_drinking** as confounder: E.coli at home is a mediator, not confounder
3.  **Source E.coli** is confounder for diarrhea model only
4.  **Water source dummies** created from WS1
5.  **Country dummies** created from Country
