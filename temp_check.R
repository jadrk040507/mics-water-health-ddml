library(data.table)

# Check run.R to see how subgroups are defined
source("code/config.R")
data <- haven::read_dta(DATA_FILE)

cat("RiskSource variable:\n")
cat("Class:", class(data$RiskSource), "\n")
cat("Values:", paste(sort(unique(data$RiskSource)), collapse=", "), "\n")
cat("Table:\n")
print(table(data$RiskSource, useNA="always"))

# Check what the original run.R did for subgroups
cat("\nChecking if RiskSource was used for subsampling...\n")