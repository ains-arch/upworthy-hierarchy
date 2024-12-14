# Load Data
library(ggplot2)
library(reshape2)

data <- read.csv("upworthy-archive-datasets/upworthy-archive-exploratory-packages-03.12.2020.csv")
data <- data[data$impressions > 0, ]  # filter rows with impressions

# prepare variables
clicks <- data$clicks
impressions <- data$impressions
story_id <- data$clickability_test_id
headline_id <- data

# story- and headline-level variables
story_levels <- unique(story_id)
I <- length(story_levels)  # number of stories
J <- max(table(story_id))  # max headlines per story
y <- as.matrix(read.csv('cleaned_data/y_matrix.csv', row.names=1))
n <- as.matrix(read.csv('cleaned_data/n_matrix.csv', row.names=1))

# initialize hyperpriors
# hyperprior gamma parameters
x1 <- 1; x2 <- 1; x3 <- 1; x4 <- 1
x5 <- 1; x6 <- 1; x7 <- 1; x8 <- 1

# hierarchical priors
# hyperparameters for alpha and beta
A <- rgamma(1, x1, x2)
B <- rgamma(1, x3, x4)
C <- rgamma(1, x5, x6)
D <- rgamma(1, x7, x8)

# story-specific parameters
alpha <- rgamma(I, A, C)
beta <- rgamma(I, B, D)

# Gibbs sampling loop
# number of chains
n_chains <- 5
n_iter <- 1000  # number of iterations per chain

# storage for all chains
all_samples <- vector("list", n_chains)
for (chain in 1:n_chains) {
  print(paste("Starting chain", chain))
  
  # initialize chain-specific parameters
  A <- rgamma(1, x1, x2)
  B <- rgamma(1, x3, x4)
  C <- rgamma(1, x5, x6)
  D <- rgamma(1, x7, x8)
  alpha <- rgamma(I, A, C)
  beta <- rgamma(I, B, D)
  
  # storage for samples in this chain
  chain_samples <- list(
    alpha = matrix(NA, nrow = n_iter, ncol = I),
    beta = matrix(NA, nrow = n_iter, ncol = I),
    p = array(NA, c(n_iter, I, J))
  )
  
  # Gibbs loop for this chain
  for (t in 1:n_iter) {
    # update p_ij
    for (i in 1:I) {
      for (j in 1:J) {
        if (!is.na(y[i, j])) {
          p <- rbeta(1, alpha[i] + y[i, j], beta[i] + n[i, j] - y[i, j])
          chain_samples$p[t, i, j] <- p
        }
      }
    }

    # update alpha_i and beta_i
    for (i in 1:I) {
      alpha[i] <- rgamma(1, A + sum(y[i, ]), C + sum(n[i, ]))
      beta[i] <- rgamma(1, B + sum(n[i, ] - y[i, ]), D + sum(n[i, ]))
      chain_samples$alpha[t, i] <- alpha[i]
      chain_samples$beta[t, i] <- beta[i]
    }

    # update hyperparameters
    A <- rgamma(1, x1 + sum(alpha), x2 + I)
    B <- rgamma(1, x3 + sum(beta), x4 + I)
    C <- rgamma(1, x5 + sum(alpha), x6 + I)
    D <- rgamma(1, x7 + sum(beta), x8 + I)
  }

  # save this chain's samples
  all_samples[[chain]] <- chain_samples
}

# calculate average alpha per iteration for each chain
alpha_averages <- sapply(all_samples, function(chain_samples) {
  rowMeans(chain_samples$alpha, na.rm = TRUE)
})

# convert to data frame for plotting
trace_data <- data.frame(
  Iteration = rep(1:n_iter, n_chains),
  AverageAlpha = as.vector(alpha_averages),
  Chain = factor(rep(1:n_chains, each = n_iter))
)

# create a combined trace plot
ggplot(trace_data, aes(x = Iteration, y = AverageAlpha, color = Chain)) +
  geom_line() +
  labs(title = "Trace Plot of Average Alpha Across Chains",
       x = "Iteration",
       y = "Average Alpha",
       color = "Chain") +
  theme_minimal() +
  theme(
    panel.background = element_rect(fill = "white", color = NA),
    plot.background = element_rect(fill = "white", color = NA) 
  )

# save the plot
ggsave("figs/combined_trace_plot.png", width = 8, height = 6)

# compute the mean clickthrough rate for each story across iterations
story_means <- apply(all_samples[[1]]$p, c(2), mean, na.rm = TRUE)

# compute the variance of these story means
variance_of_means <- var(story_means, na.rm = TRUE)

cat("Variance of mean clickthrough rates across stories:", variance_of_means, "\n")

# heat map of mean clickthrough rates (p_ij)
# compute mean probabilities for each story across iterations
heatmap_data <- apply(all_samples[[1]]$p, c(2, 1), mean, na.rm = TRUE)

# convert to data frame for plotting
heatmap_df <- melt(heatmap_data)
colnames(heatmap_df) <- c("Story", "Iteration", "MeanProbability")

# create heat map
ggplot(heatmap_df, aes(x = Iteration, y = Story, fill = MeanProbability)) +
  geom_tile() +
  scale_fill_gradient2(low = "blue", high = "red", mid = "white", midpoint = 0.5, limits = c(0, 1)) +
  labs(title = "Heat Map of Mean Clickthrough Rates Over Iterations",
       x = "Iteration",
       y = "Story",
       fill = "Mean CTR") +
  theme_minimal() +
  theme(
    panel.background = element_rect(fill = "white", color = NA),
    plot.background = element_rect(fill = "white", color = NA)
  )

# save the heat map
ggsave("figs/heatmap_clickthrough_rates.png", width = 10, height = 8)
