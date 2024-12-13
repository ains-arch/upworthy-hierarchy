# load data
setwd("~/Documents/School/stats/final")
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
I <- length(story_levels)  # number of stories
N <- nrow(data)  # total number of rows
y <- clicks  # observed successes
n <- impressions  # total trials

# clip probabilities to avoid extreme values
epsilon <- 1e-10
p <- (y + epsilon) / (n + 2 * epsilon)

# current setup
# binomial likelihood, not normal
# for headline i in test j:
    # clicks_{ij} ~ binomial(impressions_{ij}, p_{ij})
        # a success is a click out of the total impressions (trials)
    # logit(p_{ij}) = theta_j
        # the probability that a user clicks is p_{ij}
        # bounded between 0 and 1
        # p_{ij} = \frac{e^{theta_j}}{1+e^{theta_j}} = theta_j
# priors
    # theta_j ~ N(mu, tau^2) : the test-specific log-odds of theta_j drawn from population normal
        # vary around a population mean (mu) with variability controlled by tau
        # log odds can range -inf to inf, so Normal makes sense
        # also makes this computationally reasonable
    # mu ~ N(0,10) : overall mean log-odds across tests
        # mean of 0: avoid biasing toward high or low click probabilities
        # variance of 10: significant uncertainty
    # tau ~ half-cauchy(0,5) : variability of log-odds across tests
        # weakly informative, discourages extreme values, prevents overly tight constraints
        # scale parameter of 5: moderate variability in log-odds, realistic differences across tests

# TODO: change to binomial-beta-gamma-gamma hierarchical model
# TODO: draw hierarchical model
# TODO: verify model against the other dataset
# data: y clicks in n impressions for headline j in story i
# population level
  # two hyperhyperprior gammas on A, B hyperhyperparameters
    # on the first inputs to the story hyperprior gammas
  # two hyperhyperprior gammas on C, D hyperhyperparameters
    # on the second inputs to the story hyperprior gammas
  # have to be gammas because the inputs to the hyperprior gammas have to be positive
  # A ~ gamma(x_1, x_2)
  # B ~ gamma(x_3, x_4)
  # C ~ gamma(x_5, x_6)
  # D ~ gamma(x_7, x_8)
  # i choose the 8 x hyperhyperhyperparameters, non-informative
  # everything else is informative priors, but it's informed by the data
# story i level
  # i*two hyperprior gammas on alpha_ij and beta_ij hyperparameters to beta prior distributions
  # two for each story i, which story i is more likely to get clicked
  # need to be gammas because alpha_ijs and beta_ijs have to be positive
  # alpha_i ~ gamma(A_i, C_i)
  # beta_i ~ gamma(B_i, D_i)
# headline j level
  # i*j total prior beta distributions for all the p_ijs
  # which headline j is more likely to get clicked
  # best headline j will often have the highest clickthrough rate, but it depends on sample size
  # the goal of hierarchical models is to get shrinkage without having to encode our biases
  # p_ij ~ beta(alpha_ij, beta_ij)
# i*j total binomial likelihoods
  # y_ij ~ binomial_ij(n_ij, p_ij): likelihood of click for each headline j in story i

# code for old setup
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
mu_mean <- mean(sims[, , "mu"])
tau_mean <- mean(sims[, , "tau"])

# transform back into logit
theta_probs <- inv_logit(theta_means)

# Results
# > theta_probs
# [1] 0.009899171 0.009899155 0.009899178 0.009899179 0.009899186
# chain level means of probabilities derived from log-odds parameters theta_j
# converted using logistic function
# low probability of clicks in general
# five chains, similar results -> ran for long enough
# > theta_means
# [1] -4.605356 -4.605357 -4.605355 -4.605355 -4.605354
# posterior means of log-odds theta_j, correspond to low click through rates
# prior on theta_j of N(mu, tau^2) encourages them to be close to population mean mu
# > mu_mean
# [1] -4.60536
# posterior mean, population-level log-odds across all tests
# > tau_mean
# [1] 0.897944
# posterior mean of tau, standard deviation in log-odds
# some moderate variability in test-specific log-odds
# i'm a little confused at the meaning of the output being by test vs by chain
