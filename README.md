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
TODO: add a flow chart to visualize the hiearchical model
-->

Specifically, we model the number of clicks for each headline as a Binomial outcome, with the probability of a click varying by test/story.
This makes sense for the dataset because headlines are nested within tests, and click probabilities likely vary across tests.
Every story isn't equally interesting, no matter how good the headline is.

This analysis is similar to what was done as [an example in class by the researcher who released the dataset](https://github.com/natematias/design-governance-experiments/blob/master/2020/lecture-code/lecture-17-meta-analysis.R.ipynb).
His analysis was using a mixed effects model and frequentist methodologies.
We adapt this analysis into a Bayesian framework.

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

## Initial model (`normal.R`)
In our initial approach, we modeled the data as Binomial-normal-half-Cauchy.

### Binomial likelihood
For headline $j$ for story $i$:
```math
\text{clicks}_{ij} \sim \text{binomial}(\text{impressions}_{ij}, p_{ij})
```
A success is a click out of the total impressions (trials).

The logit of $p_{ij$ is the test-specific log-odds parameter ($\theta_j$).
```math
\text{logit}(p_{ij}) = theta_j \text{, where } p_{ij} = \frac{e^{theta_j}}{1+e^{theta_j}}
```
The probability that a user clicks is $p_{ij}$.
It needs to be bounded between 0 and 1, thus the logit.

### Prior
The click-through rate for each story in log-odds ($\theta_j$) is defined by the population normal:
```math
\theta_j \sim \mathcal{N}(\mu, \tau^2)
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
We then used five chains of 10,000 steps of Gibbs sampling to iteratively update $\theta_j$ using the observed clicks, impressions, and current values of $\mu$ and $\tau$, $\mu$ using the current estimates of $\theta_j$, and $\tau$ using the spread of $\theta_j$ around $\mu$.

We collected the posterior means of $\theta_j$, $\mu$ and $\tau$, and transformed them back to probabilities using the logistic function.

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

## Future work
Another possible approach to this dataset is a change point analysis.
Additional research on the setting the data was collected in would be necessary in order to surmise if it's reasonable to expect a change point in this data.
