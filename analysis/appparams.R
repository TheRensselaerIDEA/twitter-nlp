r = getOption("repos")
r["CRAN"] = "http://cran.rstudio.com"
options(repos = r)

if (!require("DT")) {
  install.packages("DT")
  library(DT)
}

if (!require("ggplot2")) {
  install.packages("ggplot2")
  library(ggplot2)
}

if (!require("knitr")) {
  install.packages("knitr")
  library(knitr)
}

if(!require('dplyr')) {
  install.packages("dplyr")
  library(dplyr)
}

if(!require('stringr')) {
  install.packages("stringr")
  library(stringr)
}

if(!require('Rtsne')) {
  install.packages("Rtsne")
  library(Rtsne)
}

if(!require('stopwords')) {
  install.packages("stopwords")
  library(stopwords)
}

if(!require('plotly')) {
  install.packages("plotly")
  library(plotly)
}

if (!require("kableExtra")) {
  install.packages("kableExtra")
  library(kableExtra)
}

if (!require("wordcloud2")) {
  install.packages("wordcloud2")
  library(wordcloud2)
}

if (!require("tidytext")) {
  install.packages("tidytext")
  library(tidytext)
}

if (!require("tm")) {
  install.packages("tm")
  library(tm)
}

if (!require("ggrepel")) {
  install.packages("ggrepel")
  library(ggrepel)
}

if (!require("shinyWidgets")) {
  install.packages("shinyWidgets")
  library(shinyWidgets)
}

if (!require("shinycssloaders")) {
  install.packages("shinycssloaders")
  library(shinycssloaders)
}

knitr::opts_chunk$set(echo = TRUE)

source("Elasticsearch.R")

if (!require("syuzhet")) {
  install.packages("syuzhet")
  library(syuzhet)
}

if (!require("shinycssloaders")) {
  install.packages("shinycssloaders")
  library(shinycssloaders)
}

if (!require("rintrojs")) {
  install.packages("rintrojs")
  library(rintrojs)
}

if (!require("png")) {
  install.packages("png")
  library(png)
}
if (!require("shinydashboard")) {
  install.packages("shinydashbard")
  library(shinydashboard)
}

if (!require("grid")) {
  install.packages("grid")
  library(grid)
}



#range start
rangestart <- "2020-03-01 00:00:00"

#range end
rangeend <- "2020-08-01 00:00:00"

text_filter<-""

#query semantic similarity phrase 
semantic_phrase <- ""

#(ignored if semantic_phrase is not blank)
random_sample <- FALSE

#number of results to return (max 10,000)
resultsize <- 10000

show_original_subcluster_plots <- FALSE
show_regrouped_subcluster_plots <- TRUE
show_word_freqs <- FALSE
show_center_nn <- FALSE

# text filter restricts results to only those containing words, phrases, or meeting a boolean condition. This query syntax is very flexible and supports a wide variety of filter scenarios:
# words: text_filter <- "cdc nih who"  ...contains "cdc" or "nih" or "who"
# phrase: text_filter <- '"vitamin c"' ...contains exact phrase "vitamin c"
# boolean condition: <- '(cdc nih who) +"vitamin c"' ...contains ("cdc" or "nih" or "who") and exact phase "vitamin c"
#full specification here: https://www.elastic.co/guide/en/elasticsearch/reference/current/query-dsl-simple-query-string-query.html
text_filter <- ""

# location filter acts like text filter except applied to the location of the tweet instead of its text body.
location_filter <- ""

# if FALSE, location filter considers both user-povided and geotagged locations. If TRUE, only geotagged locations are considered.
must_have_geo <- FALSE

# number of results to return (max 10,000)
resultsize <- 10000
# minimum number of results to return. This should be set according to the needs of the analysis (i.e. enough samples for statistical significance)
min_results <- 500

