# Info for Health Analytics Challenge Lab (HACL Summer 2020)

## Getting started
1. Review the [README](https://github.com/TheRensselaerIDEA/COVID-Twitter/blob/master/README.md). Follow the directions to get started on the Rensselaer IDEA cluster and knit the semantic_search.Rmd and twitter.Rmd notebooks.

2. The HACL will also be using the COVID-19 Events tweet dataset provided for [this EMNLP 2020 competition](http://noisy-text.github.io/2020/extract_covid19_event-shared_task.html). This dataset has been pre-loaded into the IDEA elasticsearch cluster as the index named `covidevents-data`.
  
    Two notebooks exist to work with this data:

    * [twitter_covidevents.Rmd](https://github.com/TheRensselaerIDEA/COVID-Twitter/blob/master/analysis/twitter_covidevents.Rmd) is based on [twitter.Rmd](https://github.com/TheRensselaerIDEA/COVID-Twitter/blob/master/analysis/twitter.Rmd) and contains additional code to read out and display the classification metadata provided for each tweet as described in the [dataset paper](https://arxiv.org/abs/2006.02567).

    * [covid-twitter-hacl-template.Rmd](https://github.com/TheRensselaerIDEA/COVID-Twitter/blob/master/analysis/covid-twitter-hacl-template.Rmd) is a notebook template for performing a statistical or discursive study on the tweets in this dataset. The template contains a basic content outline and also includes the relevant boilerplate code for theme/topic clustering and labeling. This boilerplate code can be removed from your final notebook if your study does not need to perform theme/topic clustering.

    Additionally, pre-rendered examples of the notebooks exist in the [examples](https://github.com/TheRensselaerIDEA/COVID-Twitter/tree/master/analysis/examples) directory for easy reference without knitting anything.

## Communication & collaboration
We will be using the #idea-covid-twitter channel in the Rensselaer IDEA slack workspace.