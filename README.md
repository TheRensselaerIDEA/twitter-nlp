# COVID-Twitter

## Project overview resources
The following resources provide an overview of the project:
- [Overview slides](https://docs.google.com/presentation/d/1iXgehix_hE_sg2qoOrDjCVfGvFRE5lFXISznNnNdklg/edit?usp=sharing)
- [IDEA poster](https://drive.google.com/file/d/1Y66aMfGIjqbTeUX0RMQ-RpjA1u7pEWVJ/view?usp=sharing)
- [UG Research Symposium poster slides](https://drive.google.com/file/d/13U5hQeKTnfd3I1oSDLsbVIFXPj1xX5gf/view?usp=sharing)

## Getting started 
### On the Rensselaer IDEA cluster
1. Clone this repository to your preferred location on the cluster (home directory, etc.)

2. Modify your local copies of [semantic_search.Rmd](https://github.com/TheRensselaerIDEA/COVID-Twitter/blob/master/analysis/semantic_search.Rmd) and [twitter.Rmd](https://github.com/TheRensselaerIDEA/COVID-Twitter/blob/master/analysis/twitter.Rmd) by inserting the hostname of the elasticsearch server into the line `elasticsearch_host=""`. See the project slack channel **#idea-covid-twitter** to get the hostname.

    **Note**: the hostname should be removed before committing changes to this repository.

3. In RStudio, knit both of these notebooks. They may take a few minutes to run depending on the search parameters.

### On a local machine
COMING SOON!

## Using the notebooks
Both [semantic_search.Rmd](https://github.com/TheRensselaerIDEA/COVID-Twitter/blob/master/analysis/semantic_search.Rmd) and [twitter.Rmd](https://github.com/TheRensselaerIDEA/COVID-Twitter/blob/master/analysis/twitter.Rmd) are meant to be knit to HTML. Only run the Rmd directly in RStudio when working on parts of the code. Note that the HTML output will not render correctly in RStudio, so results need to be viewed as DataFrames instead when working in this mode.

### Common parameters
Both notebooks accept a date range, semantic phrase, and result size:

#### Date range
This filters the date range for which tweets will be retrieved. In general, larger date ranges take longer to run. The query below retrieves tweets from April 1 to April 15. The `rangeend` parameter is exclusive, meaning that tweets occuring at midnight April 16th are not returned.
```{r}
# query start date/time (inclusive)
rangestart <- "2020-04-01 00:00:00"

# query end date/time (exclusive)
rangeend <- "2020-04-16 00:00:00"
```

**Note when running on the IDEA cluster:** Due to storage limitations, not all collected tweets have their embeddings computed and stored in Elasticsearch. For best results, restrict queries to dates within the following ranges on which there exist more than 100,000 embedded tweets per day:
- March 17 - April 16 (inclusive)
- April 23 - April 25 (inclusive)

This list will be updated when storage capacity increases and more tweets are embedded.

#### Semantic phrase
A semantic phrase causes retrieved tweets to be ordered by cosine similarity with the embedding of this phrase.
```{r}
# query semantic similarity phrase (choose one of these examples or enter your own)
#semantic_phrase <- "I lost my job because of COVID-19. How am I going to be able to make rent?"
```

#### Result size
Number of tweets to retrieve.
```{r}
# number of results to return (max 10,000)
resultsize <- 10000
```

### Paramaters for semantic_search.Rmd
This notebook just uses the common search parameters, however `resultsize` should be restricted to a number that can reasonably be displayed (less than 1000).

### Parameters for twitter.Rmd
This notebook uses the common search parameters and an additional parameter for random sampling:

#### Random sampling
If `semantic_phrase` is blank, this flag indicates if tweets should be returned in ascending chronological order or as a random distribution across the date range. It typically makes sense to enable this when not using a semantic phrase, since in chronological order the first 10,000 tweets likely occur within the first minute of the date range.
```{r}
# return results in chronological order or as a random sample within the range
# (ignored if semantic_phrase is not blank)
random_sample <- TRUE
```

#### Temporary clustering settings
Change `k` and `cluster.k` to change the number of k-means clusters and subclusters respectively.
```{r}
# number of high level clusters (temporary until automatic selection implemented)
k <- if (semantic_phrase=="") 15 else 5
# number of subclusters per high level cluster (temporary until automatic selection implemented)
cluster.k <- 8
```
By default the k-means elbow plot is not run, but this can be enabled by uncommenting the line `#wssplot(tweet.vectors.matrix)`

These settings are intented to be removed when they are no longer necessary.

#### Temporary display settings
These settings show/hide additional information about each cluster and subcluster. It could be informative to knit the notebook at least once with all of these set to `TRUE`.
```{r}
# show/hide extra info (temporary until tabs are implemented)
show_original_subcluster_plots <- FALSE
show_regrouped_subcluster_plots <- TRUE
show_word_freqs <- FALSE
show_center_nn <- FALSE
```

## TweetID dataset
The TweetID dataset has been moved [to its own repository](https://github.com/TheRensselaerIDEA/COVID-TweetIDs).