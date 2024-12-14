# Hierarchical Model Code
# 1. Load Data
setwd("~/Documents/School/stats/final")
# install.packages("ggplot2")
library(ggplot2)
# install.packages("reshape2")
library(reshape2)

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
y <- as.matrix(read.csv('cleaned_data/y_matrix.csv', row.names=1))
n <- as.matrix(read.csv('cleaned_data/n_matrix.csv', row.names=1))

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
# Number of chains
n_chains <- 5
n_iter <- 100  # Number of iterations per chain

# Storage for all chains
all_samples <- vector("list", n_chains)
for (chain in 1:n_chains) {
  print(paste("Starting chain", chain))
  
  # Initialize chain-specific parameters
  A <- rgamma(1, x1, x2)
  B <- rgamma(1, x3, x4)
  C <- rgamma(1, x5, x6)
  D <- rgamma(1, x7, x8)
  alpha <- rgamma(I, A, C)
  beta <- rgamma(I, B, D)
  
  # Storage for samples in this chain
  chain_samples <- list(
    alpha = matrix(NA, nrow = n_iter, ncol = I),
    beta = matrix(NA, nrow = n_iter, ncol = I),
    p = array(NA, c(n_iter, I, J))
  )
  
  # Gibbs loop for this chain
  for (t in 1:n_iter) {
    # Update p_ij
    for (i in 1:I) {
      for (j in 1:J) {
        if (!is.na(y[i, j])) {
          p <- rbeta(1, alpha[i] + y[i, j], beta[i] + n[i, j] - y[i, j])
          chain_samples$p[t, i, j] <- p
        }
      }
    }

    # Update alpha_i and beta_i
    for (i in 1:I) {
      alpha[i] <- rgamma(1, A + sum(y[i, ]), C + sum(n[i, ]))
      beta[i] <- rgamma(1, B + sum(n[i, ] - y[i, ]), D + sum(n[i, ]))
      chain_samples$alpha[t, i] <- alpha[i]
      chain_samples$beta[t, i] <- beta[i]
    }

    # Update hyperparameters
    A <- rgamma(1, x1 + sum(alpha), x2 + I)
    B <- rgamma(1, x3 + sum(beta), x4 + I)
    C <- rgamma(1, x5 + sum(alpha), x6 + I)
    D <- rgamma(1, x7 + sum(beta), x8 + I)
  }

  # Save this chain's samples
  all_samples[[chain]] <- chain_samples
}

# Calculate average alpha per iteration for each chain
alpha_averages <- sapply(all_samples, function(chain_samples) {
  rowMeans(chain_samples$alpha, na.rm = TRUE)
})

# Convert to data frame for plotting
trace_data <- data.frame(
  Iteration = rep(1:n_iter, n_chains),
  AverageAlpha = as.vector(alpha_averages),
  Chain = factor(rep(1:n_chains, each = n_iter))
)

# Create a combined trace plot
ggplot(trace_data, aes(x = Iteration, y = AverageAlpha, color = Chain)) +
  geom_line() +
  labs(title = "Trace Plot of Average Alpha Across Chains",
       x = "Iteration",
       y = "Average Alpha",
       color = "Chain") +
  theme_minimal()

# Save the plot
ggsave("figs/combined_trace_plot.png", width = 8, height = 6)

# Compute the mean clickthrough rate for each story across iterations
story_means <- apply(all_samples[[1]]$p, c(2), mean, na.rm = TRUE)

# Compute the variance of these story means
variance_of_means <- var(story_means, na.rm = TRUE)

cat("Variance of mean clickthrough rates across stories:", variance_of_means, "\n")


