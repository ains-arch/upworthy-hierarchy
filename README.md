# Upworthy Research Archive Hierarchical Model
In this project, we describe and begin implementation of a hierarchical model using the Upworthy Research Archive dataset.
This dataset contains information on A/B headline tests from Upworthy, a Buzzfeed-era digital media/advocacy company that A/B tested a lot of Facebook-optimized clickbait headlines and recently made a large dataset of results public.

The dataset centers around packages within tests, where packages are bundles of headlines and images that were randomly assigned to website viewers as part of a test.
A single test therefore includes many packages.

## Relevant dataset features
- `clickability_test_id`: the test ID. Viewers were randomly assigned to packages with the same test ID
- `impressions`: the number of viewers who were assigned to this package. The total number of participants for a given test is the sum of impressions for all packages that share the same `clickability_test_id`
- `headline`: the headline being tested
- `clicks`: the number of viewers (impressions) that clicked on the package. The click-rate for a given package is the number of clicks divided by the number of impressions.

You can read more about the structure of the dataset [here](https://upworthy.natematias.com/about-the-archive).

## Methodology
Our hierarchical model analyzes click-rates.

<!--
TODO: add a flow chart to visualize the hierarchical model
-->

Specifically, we model the number of clicks for each headline as a Binomial outcome, with the probability of a click varying by test/story.
This makes sense for the dataset because headlines are nested within tests, and click probabilities likely vary across tests.
Every story isn't equally interesting, no matter how good the headline is.

This analysis is similar to what was done as [an example in class by the researcher who released the dataset](https://github.com/natematias/design-governance-experiments/blob/master/2020/lecture-code/lecture-17-meta-analysis.R.ipynb).
His analysis was using a mixed effects model and frequentist methodologies.
We adapt this analysis into a Bayesian framework.

The goal of hierarchical models are to have priors in a Bayesian framework that are informed by the data.
They allow us to get shrinkage without having to choose priors.

## Data processing (`data_processing.py`)
We prepare clickthrough data for a hierarchical Bayesian analysis of headline performance across different stories.

- Load Upworthy clickthrough dataset
- Clean data by removing rows with invalid impressions or clicks
- Aggregate data by unique story and headline combinations
- Handle variations in headline count across stories
- Create two matrices:
  - `y`: Total clicks per story and headline
  - `n`: Total impressions per story and headline
- Export matrices as CSV files for use in R-based analysis
  - `data/y_matrix.csv`: Matrix of click counts
  - `data/n_matrix.csv`: Matrix of impression counts

## Binomial-Normal (`normal.R`)
In our initial approach, we modeled the data as Binomial-Normal-Half-Cauchy.

### Binomial likelihood
For headline $j$ for story $i$:
```math
y_{ij} \sim \text{Binomial}(n_{ij}, p_{ij})
```
A success is a click out of the total impressions (trials).

The logit of $p_{ij}$ is the story-specific log-odds parameter ($\theta_i$).
```math
\text{logit}(p_{ij}) = theta_i \text{, where } p_{ij} = \frac{e^{theta_i}}{1+e^{theta_i}}
```
The probability that a user clicks is $p_{ij}$.
It needs to be bounded between 0 and 1, thus the logit.

### Prior
The click-through rate for each story in log-odds ($\theta_i$) is defined by the population normal:
```math
\theta_i \sim \mathcal{N}(\mu, \tau^2)
```
The log odds can range $-\infty$ to $\infty$, so using a normal prior makes sense.
It also makes it computationally reasonable.

### Hyperpriors for hyperparameters
The click-through rate varies around a population mean ($\mu$) log-odds with variability in log-odds controlled by ($\tau^2$).

The overall mean log-odds across stories:
```math
\mu \sim N(0,10)
```

The variability of click-through rates in log-odds across stories:
```math
\tau \sim \text{Half-Cauchy}(0, 5)
```
This allows us to discourage extreme values and prevent overly tight constraints.

### Hyperhyperparameters for hyperpriors (chosen)
For $\mu$, we chose:
- a mean of 0 to avoid biasing toward high or low click probabilities
- a variance of 10 to model significant uncertainty

For $\tau$, we chose:
- a location parameter of 0
- a scale parameter of 5 to allow moderate variability in log-odds, realistic differences across tests

### Method
We then used five chains of 10,000 steps of Gibbs sampling to iteratively update $\theta_i$ using the observed clicks, impressions, and current values of $\mu$ and $\tau$, $\mu$ using the current estimates of $\theta_i$, and $\tau$ using the spread of $\theta_i$ around $\mu$.

We collected the posterior means of $\theta_i$, $\mu$ and $\tau$, and transformed them back to probabilities using the logistic function.

### Results
Our results showed:
```R
> theta_probs
[1] 0.009899171 0.009899155 0.009899178 0.009899179 0.009899186
```
The average posterior probabilities across five chains are all around 0.0099, showing very low click-through rates.

```R
> tau_mean
[1] 0.897944
```
At the population level, this indicates moderate variability in click-through rates between stories.

### Discussion
Our choice of prior for $\mu$ assumes no strong bias toward high of low click-through rates, but this is not borne out by the data.
As such, this could affect results.

Additionally, with click through rates as low as they are, the approach to handling non-negative probabilities by adding epsilon might artificially inflate probabilities in a significant way.

## Beta-Binomial model (`beta.R`)
In our final approach, we modeled the data as Gamma-Gamma-Beta-Binomial.

<img src=figs/model.png/>

### Binomial likelihood
We again model clicks, for headline $j$ and story $i$:
```math
y_{ij} \sim \text{Binomial}(n_{ij}, p_{ij})
```
There are $i*j$ total binomial likelihoods, one for each row in the dataset.

### Headline level
At the headline level, we have $i*j$ total beta distributions as priors for all the $p_{ij}$s.
```math
p_{ij} \sim \text{beta}(\alpha_{ij}, \beta_{ij})
```
This is modeling our uncertainty over how likely headlines are to get clicked.
The best headline will often have the highest click-through rate, but with low sample sizes, that isn't necessarily the case.

### Story level
At the story level, we have $2i$ total gamma distributions as hyperpriors on $\alpha_{ij}$ and $\beta_{ij}$.
There are two for each story, and model which story is more likely to get clicked.
We use gamma distributions because $\alpha_{ij}$s and $\beta{ij}$s have to be positive.

```math
\alpha_i \sim \text{gamma}(A_i, C_i)
\beta_i \sim \text{gamma}(B_i, D_i)
```

### Population level
At the population level, we have four total gamma distributions as hyperhyperpriors on the hyperparameters for the gamma hyperpriors: two gamma distributions for $A$ and $B$ (the first inputs to the gamma hyperpriors) and two gamma distributions for $C$ and $D$ (the second inputs to the gamma hyperpriors).
We again use gamma distributions because $A$, $B$, $C$, and $D$ have to be positive.

```math
A \sim \text{gamma}(x_1, x_2) 
B \sim \text{gamma}(x_3, x_4) 
C \sim \text{gamma}(x_5, x_6) 
D \sim \text{gamma}(x_7, x_8) 
```

We chose the eight hyperhyperhyperparameter $x$s as non-informative $x=1$.
All other priors are informative priors, but they are informed by the data rather than our prior knowledge.

### Results
First, a trace plot showing convergence in the mean $\alpha$ across the stories.
This is a contrived variable, but it allows us to look at a single measure across the five chains.
<img src=figs/combined_trace_plot.png/>

Next, a heat map of the clickthrough rates in the first chain by stories as the chain progresses.
<img src=figs/heatmap_clickthrough_rates.png/>

To look at if a difference in story makes a difference in the clickthrough rate, we check the variance of the mean clickthrough rates across stories: $0.0001507662$.

So, no? Or there's something wrong with the code. Impossible to say. ...Thanks for reading.
