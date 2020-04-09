# COVID-Twitter

## Project overview
See [project overview slides](https://docs.google.com/presentation/d/1iXgehix_hE_sg2qoOrDjCVfGvFRE5lFXISznNnNdklg/edit?usp=sharing)

## Data Collection and Sharing

### Data Sharing Format
Per [Twitter's terms of serivce for content redistribution](https://developer.twitter.com/en/developer-terms/agreement-and-policy) we provide lists of Tweet IDs which can be found [here](data_collection/tweet_ids). Each month of tweets gets its own folder containing one text file per hour named with the date and UTC hour.

### Collection strategy (as of 3/21/2020):
We use the twitter streaming API to collect tweets related to keywords that are related to the ongoing coronavirus pandemic.
Filter keywords were selected based on the following methods:
- A term frequency analysis was done on a random sample of 30,000 tweets collected with keywords "coronavirus" and "covid". Of the top 200 most frequent non-stopword terms, 50 were manually selected.
- Some keywords were borrowed from a [similar effort at USC](https://arxiv.org/abs/2003.07372).
- Some keywords were added based on knowledge of emerging discussion topics related to the pandemic.

### Keyword list (as of 3/21/2020):
See [keywords.txt](data_collection/keywords.txt)

## Clustering and Analysis
Coming Soon...