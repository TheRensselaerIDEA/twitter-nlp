
if (!require("knitr")) {
  install.packages("knitr")
  library(knitr)
}

if(!require('dplyr')) {
  install.packages("dplyr")
  library(dplyr)
}

if(!require('Rtsne')) {
  install.packages("Rtsne")
  library(Rtsne)
}

if (!require("kableExtra")) {
  install.packages("kableExtra")
  library(kableExtra)
}

knitr::opts_chunk$set(echo = TRUE)





source("Elasticsearch.R")
source("Summarizer.R")
source("general_helpers.R")
source("text_helpers.R")
source("plot_helpers.R")


  # Set server resource locations here:
elasticsearch_index <- "coronavirus-data-masks"
elasticsearch_host <- ""
elasticsearch_path <- "elasticsearch"
elasticsearch_port <- 443
elasticsearch_schema <- "https"
  
summarizer_url <- ""



  # query start date/time (inclusive)
rangestart <- "2020-03-01 00:00:00"
  
  # query end date/time (exclusive)
rangeend <- "2020-08-01 00:00:00"
  
  # text filter restricts results to only those containing words, phrases, or meeting a boolean condition. This query syntax is very flexible and supports a wide variety of filter scenarios:
  # words: text_filter <- "cdc nih who"  ...contains "cdc" or "nih" or "who"
  # phrase: text_filter <- '"vitamin c"' ...contains exact phrase "vitamin c"
  # boolean condition: <- '(cdc nih who) +"vitamin c"' ...contains ("cdc" or "nih" or "who") and exact phrase "vitamin c"
  #full specification here: https://www.elastic.co/guide/en/elasticsearch/reference/current/query-dsl-simple-query-string-query.html
text_filter <- ""
  
# location filter acts like text filter except applied to the location of the tweet instead of its text body.
location_filter <- ""
  
  # if FALSE, location filter considers both user-povided and geotagged locations. If TRUE, only geotagged locations are considered.
must_have_geo <- FALSE
  
  # query semantic similarity phrase (choose one of these examples or enter your own)
  #semantic_phrase <- "Elementary school students are not coping well with distance learning."
  #semantic_phrase <- "I am diabetic and out of work because of coronavirus. I am worried I won't be able to get insulin without insurance."
semantic_phrase <- ""
  
  # sentiment type (only 'vader' is supported for now)
  # if the requested sentiment type is not available for the current index or sample, the sentiment
  # column in the result set will contain NA values.
sentiment_type <- "vader"
  
  # query lower bound for sentiment (inclusive). Enter a numeric value or for no lower bound set to NA.
sentiment_lower <- NA
  
  # query upper bound for sentiment (inclusive). Enter a numeric value or for no upper bound set to NA.
sentiment_upper <- NA
  
  # return results in chronological order or as a random sample within the range
  # (ignored if semantic_phrase is not blank)
random_sample <- TRUE
  
  # number of results to return (to return all results, set to NA)
resultsize <- 10000
  
  # minimum number of results to return. This should be set according to the needs of the analysis (i.e. enough samples for statistical significance)
min_results <- 500



  #--------------------------
  # PSEUDORANDOM SEEDS
  #--------------------------
  # Optionally specify seeds for reproducibility. For no seed, set to NA on any of these settings.
  # seed for random sampling (if enabled)
random_seed <- 100
  # seed for k-means
kmeans_clusters_seed <- 300
kmeans_subclusters_seed <- 500
  # seed for t-sne
tsne_clusters_seed <- 700
tsne_subclusters_seed <- 900
  
  #--------------------------
  # K-MEANS HYPERPARAMS
  #--------------------------
  # range of k choices to test for elbow and silhouette plots
k_test_range <- 2:40
  
  # number of random starts
kmeans_nstart <- 25
  
  # maximum iterations
kmeans_max_iter <- 200
  
  # number of high level clusters (temporary until automatic selection implemented)
k <- 15
  
  # number of subclusters per high level cluster (temporary until automatic selection implemented)
cluster.k <- 15
  
  #--------------------------
  # LABELING HYPERPARAMS
  #--------------------------
  # Construct master label using top-k words across the entire sample
master_label_top_k <- 8
  
  # Construct cluster labels using top-k words across each cluster
cluster_label_top_k <- 3
  
  # Construct subcluster labels using top-k words across each subcluster
subcluster_label_top_k <- 3
  
  #--------------------------
  # SUMMARIZATION HYPERPARAMS
  #--------------------------
  # number of nearest neighbors to the center to use for cluster & subcluster summarization
summarize_center_nn <- 20
  
  # summarization model inference hyperparameters
summarize_max_len <- 120
summarize_num_beams <- 6
summarize_temperature <- 1.0
  
  #--------------------------
  # T-SNE HYPERPARAMS
  #--------------------------
  # hyperparams for clusters
tsne_clusters_perplexity <- 25
tsne_clusters_max_iter <- 750
  
  # hyperparams for subclusters
tsne_subclusters_perplexity <- 12
tsne_subclusters_max_iter <- 500


# plot mode - '2d' or '3d'.
# Note: if loading a snapshot, changing the plot mode will trigger T-SNE to re-run.
plot_mode <- "2d"

# If TRUE, cluster and subcluster summaries will be generated using nearest neighbors to the center.
# Note: if loading a snapshot, disabling summarization will do nothing if it was previously enabled.
summarize_clusters <- TRUE

# If TRUE, run and output k-means elbow plots
# Note: if loading a snapshot, disabling elbow plots will do nothing if they were previously enabled.
compute_elbow <- FALSE
# If TRUE, run and output k-means silhouette plots
# Note: if loading a snapshot, disabling silhouette plots will do nothing if they were previously enabled.
compute_silhouette <- FALSE

# show/hide extra info (temporary until tabs are implemented)
show_original_subcluster_plots <- FALSE
show_regrouped_subcluster_plots <- TRUE
show_word_freqs <- FALSE
show_center_nn <- FALSE

# visualize sentiment and divisiveness
show_overall_sentiment_discrete <- TRUE
show_overall_sentiment_continuous <- TRUE
show_cluster_sentiment <- TRUE
# threshold that represents the cutoff from neutral to positive above zero
# and neutral to negative below zero. Used to turn sentiment into a variable with discrete values
sentiment_threshold <- 0.05 # 0.05 recommended for VADER sentiment

# plot type for sentiment graphs
sentiment_graph_shape <- "dodge" # "dodge" for grouped, "stack" for stacked

