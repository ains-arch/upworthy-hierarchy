# load data
data <- read.csv("upworthy-archive-datasets/upworthy-archive-exploratory-packages-03.12.2020.csv")
colnames(data)

# remove rows with no impressions
data <- data[data$impressions > 0, ]

# prepare variables
clicks <- data$clicks
impressions <- data$impressions
story_id <- data$clickability_test_id 

# group data by test
story_levels <- unique(story_id)
J <- length(story_levels)  # number of stories
N <- nrow(data)  # total number of rows
y <- clicks  # observed successes
n <- impressions  # total trials

# clip probabilities to avoid extreme values
epsilon <- 1e-10
prob <- (y + epsilon) / (n + 2 * epsilon)

# posterior distribution for theta_j | data, mu, tau ~ N(theta.hat_j, sigma^2_theta_j)
# update likelihood
theta.update <- function() {
  theta.hat <- (logit(prob) * n + mu / tau^2) / (n + 1 / tau^2) # theta.hat_j
    # logit incorporates observed data
    # n impressions contributes to precision
  V.theta <- 1 / (n + 1 / tau^2) # sigma^2_theta_j
  # print(paste("theta.hat =", theta.hat, "V.theta =", V.theta))
  V.theta[V.theta < 0] <- 0  # ensure non-negative variance
  rnorm(J, theta.hat, sqrt(V.theta))
}

# define logit safely
# incorporate observed data for use in theta.update
logit <- function(p) {
  log(p / (1 - p))
}
inv_logit <- function(x) exp(x) / (1 + exp(x))  # inverse logit transformation

# update priors
# posterior mu | theta, tau ~ N(mean(theta), tau/sqrt(J))
# overall means of theta
# variance shrinks with more tests -> 1/sqrt(J)
mu.update <- function() {
  if (any(!is.finite(theta))) stop("Invalid theta values in mu.update")
  rnorm(1, mean(theta, na.rm = TRUE), tau / sqrt(J))
}
# posterior tau | theta, mu ~ hc(0, scale)
# scale is sum from j=1 to J of (theta_j - mu)^2 over df, spread of test-specific log-odds
# df is J -1, degrees of freedom adjusted for number of parameters
tau.update <- function() {
  numerator <- sum((theta - mu)^2, na.rm = TRUE)
  denominator <- rchisq(1, J - 1)
  if (denominator == 0) denominator <- 1e-10  # avoid division by zero
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
print(theta_means)
mu_mean <- mean(sims[, , "mu"])
print(mu_mean)
tau_mean <- mean(sims[, , "tau"])
print(tau_mean)

# transform back into logit
theta_probs <- inv_logit(theta_means)
print(theta_probs)
