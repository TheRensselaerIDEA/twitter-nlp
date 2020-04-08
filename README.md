# covid19_tweet_ids
Tweet IDs for COVID-19-related Twitter posts (starting March 2020)

## Project overview
See [project overview slides](https://docs.google.com/presentation/d/1iXgehix_hE_sg2qoOrDjCVfGvFRE5lFXISznNnNdklg/edit?usp=sharing)

## Data Format
Coming Soon...

## Collection strategy (as of 3/21/2020):
We use the twitter streaming API to collect tweets related to keywords that are related to the ongoing coronavirus pandemic.
Filter keywords were selected based on the following methods:
- A term frequency analysis was done on a random sample of 30,000 tweets collected with keywords "coronavirus" and "covid". Of the top 200 most frequent non-stopword terms, 50 were manually selected.
- Some keywords were borrowed from a [similar effort at USC](https://arxiv.org/abs/2003.07372).
- Some keywords were added based on knowledge of emerging discussion topics related to the pandemic.

## Keyword list (as of 3/21/2020):
See [keywords.txt](keywords.txt)