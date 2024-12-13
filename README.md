# Upworthy Research Archive Hierarchical Model
In this project, we implement a hierarchical model using the Upworthy Research Archive dataset.
This dataset contains information on A/B headline tests from Upworthy, a Buzzfeed-era digital media/advocacy company that A/B tested a lot of Facebook-optimized clickbait headlines and recently made a large dataset of results public.

The dataset centers around packages within tests, where packages are bundles of headlines and images that were randomly assigned to website viewers as part of a test.
A single test therefore includes many packages.
<!--
TODO: figure out if there's a 1:1 relationship between the tests and the stories the tests are for
-->

## Dataset features
- `created_at`: time the package was created
- `test_week`: week the package was created (engineered for stratified random sampling)
- `clickability_test_id`: the test ID. Viewers were randomly assigned to packages with the same test ID
- `impressions`: the number of viewers who were assigned to this package. The total number of participants for a given test is the sum of impressions for all packages that share the same `clickability_test_id`
- `headline`: the headline being tested
- `eyecatcher_id`: image ID (image files not included)
- `clicks`: the number of viewers (impressions) that clicked on the package. The click-rate for a given package is the number of clicks divided by the number of impressions.

You can read more about the structure of the dataset [here](https://upworthy.natematias.com/about-the-archive).

## Methodology
Our hierarchical model analyzes the click-rates.

<!--
TODO: add a flow chart to visualize the hiearchical model
-->

Specifically, we model the number of clicks for each headline as a Binomial outcome, with the probability of a click varying by test/story.
This makes sense for the dataset because headlines are nested within tests, and click probabilities likely vary across tests.
Every story isn't equally interesting, no matter how good the headline is.

This analysis is similar to what was done as [an example in class by the researcher who released the dataset](https://github.com/natematias/design-governance-experiments/blob/master/2020/lecture-code/lecture-17-meta-analysis.R.ipynb).
His analysis was using a mixed effects model and frequentist methodologies.
We adapt this analysis into a Bayesian framework, using his results to compare.

## Data processing
In addition to the core text variable of headlines, we engineer additional numeric variables.
We add:
- word count (int)
- character count (int)
- whether the headline contains (boolean):
    - numbers
    - names
    - specific keywords
        <!--
        - TODO: add keywords
        -->
- readability/complexity score

## Future work
Another possible approach to this dataset is a change point analysis.
Additional research on the setting the data was collected in would be necessary in order to surmise if it's reasonable to expect a change point in this data.
