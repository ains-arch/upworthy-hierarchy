# load data
setwd("~/Documents/School/stats/final")
data <- read.csv("upworthy-archive-datasets/upworthy-archive-exploratory-packages-03.12.2020.csv")
colnames(data)

# remove rows with no impressions
data <- data[data$impressions > 0, ]

# prepare variables
clicks <- data$clicks
impressions <- data$impressions
test_id <- data$clickability_test_id 

# group data by test
test_levels <- unique(test_id)
J <- length(test_levels)  # number of groups/tests
N <- nrow(data)  # total number of rows
y <- clicks  # observed successes
n <- impressions  # total trials

# clip probabilities to avoid extreme values
epsilon <- 1e-10
prob <- (y + epsilon) / (n + 2 * epsilon)

# binomial likelihood, not normal
    # for headline i in test j:
        # clicks_{ij} ~ binomial(impressions_{ij}, p_{ij})
        # logit(p_{ij}) = theta_j
# click probability `p` is [0,1], use a logit link function in GLM instead of normal for likelihood

# update likelihood
theta.update <- function() {
  theta.hat <- (logit(y/n) * n + mu / tau^2) / (n + 1 / tau^2)
  V.theta <- 1 / (n + 1 / tau^2)
  # print(paste("theta.hat =", theta.hat, "V.theta =", V.theta))
  V.theta[V.theta < 0] <- 0  # Ensure non-negative variance
  rnorm(J, theta.hat, sqrt(V.theta))
}

# define logit safely
logit <- function(p) {
  p <- pmax(epsilon, pmin(1 - epsilon, p))  # Clip probabilities to avoid extreme values
  log(p / (1 - p))
}
inv_logit <- function(x) exp(x) / (1 + exp(x))  # inverse logit transformation

# priors
    # theta_j ~ N(mu, tau^2) : the test-specific log-odds of theta_j drawn from population normal
    # mu ~ N(0,10) : overall mean log-odds
    # tau ~ half-cauchy(0,5) : prior for variability between tests

# update priors
mu.update <- function() {
  if (any(!is.finite(theta))) stop("Invalid theta values in mu.update")
  rnorm(1, mean(theta, na.rm = TRUE), tau / sqrt(J))
}
tau.update <- function() {
  numerator <- sum((theta - mu)^2, na.rm = TRUE)
  denominator <- rchisq(1, J - 1)
  if (denominator == 0) denominator <- 1e-10  # Avoid division by zero
  sqrt(numerator / denominator)
}

# initialize variables
n.chains <- 5
n.iter <- 10000
sims <- array (NA, c(n.iter, n.chains, J+2))
dimnames(sims) <- list (NULL, NULL, c(paste("theta[", 1:J, "]", sep=""), "mu", "tau"))
mu <- rnorm(1, mean(logit(prob), na.rm = TRUE), sd(logit(prob), na.rm = TRUE))
tau <- runif(1, 0, sd(logit(prob), na.rm = TRUE))
# print(paste("Initial mu =", mu, "Initial tau =", tau))

# gibbs sampling loop
for (m in 1:n.chains){
  mu <- rnorm(1, mean(logit(prob), na.rm = TRUE), sd(logit(prob), na.rm = TRUE))
  tau <- runif(1, 0, sd(logit(prob), na.rm = TRUE))
  for (t in 1:n.iter){
    theta <- theta.update()
    if (any(is.na(theta) | !is.finite(theta))) stop("Invalid theta values in update loop")
    mu <- mu.update()
    tau <- tau.update()
    # print(paste("Iteration", t, "theta =", theta, "mu =", mu, "tau =", tau))
    sims[t,m,] <- c(theta, mu, tau)
  }
}

# posterior means
theta_means <- apply(sims[, , 1:J], 2, mean)
mu_mean <- mean(sims[, , "mu"])
tau_mean <- mean(sims[, , "tau"])

# transform back into logit
theta_probs <- inv_logit(theta_means)
