# Hierarchical Model Code
# 1. Load Data
setwd("~/Documents/School/stats/final")
data <- read.csv("upworthy-archive-datasets/upworthy-archive-exploratory-packages-03.12.2020.csv")
data <- data[data$impressions > 0, ]  # Filter rows with impressions

# 2. Prepare Variables
clicks <- data$clicks
impressions <- data$impressions
story_id <- data$clickability_test_id
headline_id <- data

# Story- and Headline-Level Variables
story_levels <- unique(story_id)
I <- length(story_levels)  # Number of stories
J <- max(table(story_id))  # Max headlines per story
y <- as.matrix(read.csv('y_matrix.csv', row.names=1))
n <- as.matrix(read.csv('n_matrix.csv', row.names=1))

# 3. Initialize Hyperpriors
# Hyperprior gamma parameters
x1 <- 1; x2 <- 1; x3 <- 1; x4 <- 1
x5 <- 1; x6 <- 1; x7 <- 1; x8 <- 1

# 4. Hierarchical Priors
# Hyperparameters for alpha and beta
A <- rgamma(1, x1, x2)
B <- rgamma(1, x3, x4)
C <- rgamma(1, x5, x6)
D <- rgamma(1, x7, x8)

# Story-specific parameters
alpha <- rgamma(I, A, C)
beta <- rgamma(I, B, D)

# 5. Gibbs Sampling Loop
# Storage for samples
n_iter <- 10000
samples <- list(alpha = matrix(NA, nrow = n_iter, ncol = I),
                beta = matrix(NA, nrow = n_iter, ncol = I),
                p = array(NA, c(n_iter, I, J)))

print("starting gibbs")
# Gibbs loop
for (t in 1:n_iter) {
  print(t)
  # Update p_ij for each headline
  for (i in 1:I) {
    for (j in 1:J) {
      if (!is.na(y[i, j])) {
        p <- rbeta(1, alpha[i] + y[i, j], beta[i] + n[i, j] - y[i, j])
        samples$p[t, i, j] <- p
      }
    }
  }

  # Update alpha_i and beta_i
  for (i in 1:I) {
    alpha[i] <- rgamma(1, A + sum(y[i, ]), C + sum(n[i, ]))
    beta[i] <- rgamma(1, B + sum(n[i, ] - y[i, ]), D + sum(n[i, ]))
    samples$alpha[t, i] <- alpha[i]
    samples$beta[t, i] <- beta[i]
  }

  # Update A, B, C, D (hyperparameters)
  A <- rgamma(1, x1 + sum(alpha), x2 + I)
  B <- rgamma(1, x3 + sum(beta), x4 + I)
  C <- rgamma(1, x5 + sum(alpha), x6 + I)
  D <- rgamma(1, x7 + sum(beta), x8 + I)
}
