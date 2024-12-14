# Working environment
setwd("~/Documents/School/stats/final")
# sys.setenv(TEXINPUTS = "/usr/local/texlive/2024/texmf-dist/tex//:")
install.packages("dplyr")
install.packages("data.table")
library(dplyr)
library(data.table)

# Load data
data <- read.csv("upworthy-archive-datasets/upworthy-archive-exploratory-packages-03.12.2020.csv")

# Convert to data.table
dt <- as.data.table(data)

# Select relevant columns and filter
data_clean <- dt[
  !is.na(clickability_test_id) &
  !is.na(headline) &
  !is.na(impressions) &
  !is.na(clicks) &
  impressions > 0 &
  clicks > 0,
  .(clickability_test_id, headline, impressions, clicks)
]

print("data cleaned")

# Group and summarize by test and headline
data_grouped <- data_clean |>
  group_by(clickability_test_id, headline) |>
  summarize(
    total_clicks = sum(clicks),
    total_impressions = sum(impressions),
    .groups = "drop"
  )

print("data grouped")

# Create matrices for Bayesian analysis
test_ids <- unique(data_grouped$clickability_test_id)
headline_ids <- unique(data_grouped$headline)

# Initialize matrices
y <- matrix(0, nrow = length(test_ids), ncol = length(headline_ids))
n <- matrix(0, nrow = length(test_ids), ncol = length(headline_ids))

# Fill matrices
print(length(test_ids))
for (i in seq_along(test_ids)) {
  print(i)
  for (j in seq_along(headline_ids)) {
    row <- data_grouped |>
      filter(clickability_test_id == test_ids[i] & headline == headline_ids[j])
    if (nrow(row) > 0) {
      y[i, j] <- row$total_clicks
      n[i, j] <- row$total_impressions
    }
  }
}

# Check matrices
head(y)
head(n)
