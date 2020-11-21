
# Required R package installation:
# These will install packages if they are not already installed
# Set the correct default repository


#Load snapshot if snapshot mode is 'load'

source("Elasticsearch.R")
source("Summarizer.R")
source("general_helpers.R")
source("text_helpers.R")
source("plot_helpers.R")
source("plot_tweet_timeseries.R")

TweetSearch <- function(SemanticPhrase,Aspect1,Aspect2,RangeStart,RangeEnd,kValue,ResultSize){
# Set server resource locations here:
  elasticsearch_index <- "coronavirus-data-pubhealth-quotes"
  elasticsearch_host <- "lp01.idea.rpi.edu"
  elasticsearch_path <- "elasticsearch"
  elasticsearch_port <- 443
  elasticsearch_schema <- "https"
  embedder_url <- "http://localhost:8008/embed/use_large/"
  summarizer_url <- "http://idea-node-05:8080/batchsummarize"
  


### Configure the search parameters here:

  # query start date/time (inclusive)
  rangestart <- RangeStart
  
  # query end date/time (exclusive)
  rangeend <- RangeEnd
  
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
  semantic_phrase <- SemanticPhrase
  aspect1 <- Aspect1
  aspect2 <- Aspect2
  
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
  resultsize <- ResultSize
  
  # minimum number of results to return. This should be set according to the needs of the analysis (i.e. enough samples for statistical significance)
  min_results <- 1

### Configure the hyperparameters here:

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
  kmeans_nstart <- 5
  
  # maximum iterations
  kmeans_max_iter <- 200
  
  # number of high level clusters
  k <- kValue
  
  # number of subclusters per high level cluster
  cluster.k <- 10
  
  #--------------------------
  # LABELING HYPERPARAMS
  #--------------------------
  # Construct master label using top-k words across the entire sample
  master_label_top_k <- 6
  
  # Construct cluster labels using top-k words across each cluster
  cluster_label_top_k <- 3
  
  # Construct subcluster labels using top-k words across each subcluster
  subcluster_label_top_k <- 3
  
  #--------------------------
  # SUMMARIZATION HYPERPARAMS
  #--------------------------
  # number of nearest neighbors to the center to use for subcluster summarization
  summarize_center_nn <- 20
  
  # summarization model inference hyperparameters
  summarize_model <- "sshleifer/distilbart-xsum-12-6"
  summarize_max_len <- 60
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

### Configure the output settings here:
# plot mode - '2d' or '3d'.
# Note: if loading a snapshot, changing the plot mode will trigger T-SNE to re-run.
plot_mode <- "2d"

# If TRUE, cluster and subcluster summaries will be generated using nearest neighbors to the center.
# Note: if loading a snapshot, disabling summarization will do nothing if it was previously enabled.
summarize_clusters <- TRUE
# True to show a listing of all cluster & subcluster summaries
show_summaries_table <- TRUE

# If TRUE, run and output k-means elbow plots
# Note: if loading a snapshot, disabling elbow plots will do nothing if they were previously enabled.
compute_elbow <- FALSE
# If TRUE, run and output k-means silhouette plots
# Note: if loading a snapshot, disabling silhouette plots will do nothing if they were previously enabled.
compute_silhouette <- FALSE

# show/hide extra info (temporary until tabs are implemented)
show_original_subcluster_plots <- FALSE
show_regrouped_subcluster_plots <- TRUE
show_word_scores <- FALSE
show_center_nn <- FALSE

# visualize sentiment and divisiveness
show_overall_sentiment_discrete <- TRUE
show_overall_sentiment_map <- TRUE
show_overall_sentiment_continuous <- FALSE
show_cluster_sentiment_continuous <- FALSE
show_cluster_sentiment_discrete <- FALSE
show_cluster_divisiveness <- FALSE
# threshold that represents the cutoff from neutral to positive above zero
# and neutral to negative below zero. Used to turn sentiment into a variable with discrete values
sentiment_threshold <- 0.05 # 0.05 recommended for VADER sentiment
# sentiment plots start date (set NA to infer from search results)
plot_range_start <- "2020-03-15"
# sentiment plots end date (set NA to infer from search results)
plot_range_end <- NA
# perform linear regression analysis on weekly divisiveness
perform_divisiveness_linreg <- FALSE

###############################################################################
# Get the tweets from Elasticsearch using the search parameters defined above
###############################################################################

  resultfields <- '"id_str", 
                    "created_at", 
                    "user.screen_name", 
                    "user.verified", 
                    "user.location",
                    "normalized_state",
                    "place.full_name", 
                    "place.country", 
                    "text", 
                    "full_text", 
                    "extended_tweet.full_text", 
                    "quoted_status.id_str", 
                    "quoted_status.created_at", 
                    "quoted_status.user.screen_name", 
                    "quoted_status.user.verified", 
                    "quoted_status.user.location", 
                    "quoted_status.place.full_name", 
                    "quoted_status.place.country", 
                    "quoted_status.text", 
                    "quoted_status.full_text", 
                    "quoted_status.extended_tweet.full_text",
                    "embedding.use_large.primary",
                    "embedding.use_large.quoted"'
  
  results <- do_search(indexname=elasticsearch_index, 
                       rangestart=rangestart,
                       rangeend=rangeend,
                       text_filter=text_filter,
                       location_filter=location_filter,
                       semantic_phrase=semantic_phrase,
                       must_have_embedding="embedding.use_large.quoted",
                       must_have_geo=must_have_geo,
                       sentiment_type=sentiment_type,
                       sentiment_lower=sentiment_lower,
                       sentiment_upper=sentiment_upper,
                       random_sample=random_sample,
                       random_seed=random_seed,
                       resultsize=resultsize,
                       resultfields=resultfields,
                       elasticsearch_host=elasticsearch_host,
                       elasticsearch_path=elasticsearch_path,
                       elasticsearch_port=elasticsearch_port,
                       elasticsearch_schema=elasticsearch_schema,
                       embed_use_large_url=embedder_url)
  
  if (!("normalized_state" %in% colnames(results$df))) { results$df$normalized_state = NA }
  if (!("place.full_name" %in% colnames(results$df))) { results$df$place.full_name = NA }
  if (!("place.country" %in% colnames(results$df))) { results$df$place.country = NA }
  if (!("quoted_status.normalized_state" %in% colnames(results$df))) { results$df$quoted_status.normalized_state = NA }
  if (!("quoted_status.place.full_name" %in% colnames(results$df))) { results$df$quoted_status.place.full_name=NA }
  if (!("quoted_status.place.country" %in% colnames(results$df))) { results$df$quoted_status.place.country=NA }
  
  # this dataframe contains the tweet text and other metadata.
  # validate that all necessary fields exist in the queried index and were returned:
  required_fields <- c("id_str", 
                        "created_at", 
                        "user_screen_name", 
                        "user_verified", 
                        "user_location", 
                        "normalized_state",
                        "place.country", 
                        "place.full_name", 
                        "full_text",
                        "sentiment")
  # validate_results(results, min_results, required_fields)
  tweet.vectors.df <- results$df[,required_fields]
  
  # this dataframe contains the quoted text and other metadata.
  # validate that all necessary fields exist in the queried index and were returned:
  quoted_required_fields <- c("quoted_status.id_str", 
                              "quoted_status.created_at", 
                              "quoted_status.user_screen_name", 
                              "quoted_status.user_verified", 
                              "quoted_status.user_location",
                              "quoted_status.normalized_state",
                              "quoted_status.place.country", 
                              "quoted_status.place.full_name", 
                              "quoted_status.full_text",
                              "quoted_status.sentiment")
  #validate_results(results$df, min_results, quoted_required_fields)
  quoted.vectors.df <- results$df[,quoted_required_fields]
  colnames(quoted.vectors.df) <- sub("quoted_status.", "", colnames(quoted.vectors.df))
  
  # this matrix contains the embedding vectors for every tweet in tweet.vectors.df
  tweet.vectors.matrix <- t(simplify2array(results$df[,"embedding.use_large.primary"]))
  # this matrix contains the embedding vectors for every quoted tweet in quoted.vectors.df
  quoted.vectors.matrix <- t(simplify2array(results$df[,"embedding.use_large.quoted"]))


###############################################################################
# Clean the tweet and user location text, and set up tweet.vectors.df 
# the way we want it by consolidating the location field and computing
# location type
###############################################################################
  tweet.vectors.df <- prepare_location_and_text(tweet.vectors.df)
  quoted.vectors.df <- prepare_location_and_text(quoted.vectors.df)
###############################################################################
# Cleaning for HT data 
# Clean the tweet and user location text, and set up tweet.vectors.df 
# the way we want it by consolidating the location field and computing
# location type
###############################################################################
tweets.df <- tweet.vectors.df[!is.na(tweet.vectors.df$sentiment),]
  # test to see if Normalized State is avaible 
  tweets.df <- tweets.df[!is.na(tweets.df$normalized_state),]
  tweets.df$created_at <- as.POSIXct(strptime(tweets.df$created_at, format="%a %b %d %H:%M:%S +0000 %Y", tz="UTC"))
  tweets.df$week <- epiweek(tweets.df$created_at)  # CDC epidemiological week
  tweets.df$date <- date(tweets.df$created_at)
  tweet.tibble <- tibble(sentiment = tweets.df$sentiment, week = tweets.df$week, date = tweets.df$date, datetime = tweets.df$created_at, location = tweets.df$normalized_state  )
  summary.tibble <- tweet.tibble %>% group_by(location) %>% summarise(count = length(datetime),mean_sentiment = mean(sentiment))
  summary.tibble <- summary.tibble %>% ungroup()
  states <- states(cb=T)

###############################################################################
# Run K-means on all the quoted embedding vectors  [Done]
###############################################################################

  if (!is.na(kmeans_clusters_seed)) {
    set.seed(kmeans_clusters_seed)
  }
  km <- kmeans(quoted.vectors.matrix, centers=k, iter.max=kmeans_max_iter, nstart=kmeans_nstart)
  
  tweet.vectors.df$vector_type <- factor("tweet", levels=c("tweet", "cluster_center", "subcluster_center"))
  tweet.vectors.df$cluster <- km$cluster
  quoted.vectors.df$vector_type <- tweet.vectors.df$vector_type
  quoted.vectors.df$cluster <- km$cluster
  
  #append cluster centers to dataset for visualization
  centers.df <- data.frame(full_text=paste("Cluster (", rownames(km$centers), ") Center", sep=""),
                           id_str="[N/A]",
                           created_at="[N/A]",
                           user_screen_name="[N/A]",
                           user_verified="[N/A]",
                           user_location="[N/A]",
                           normalized_state="[N/A]",
                           user_location_type = "[N/A]",
                           sentiment = NA,
                           vector_type = "cluster_center",
                           cluster=as.integer(rownames(km$centers)))
  tweet.vectors.df <- rbind(tweet.vectors.df, centers.df)
  tweet.vectors.matrix <- rbind(tweet.vectors.matrix, zeros(nrow(km$centers), ncol(km$centers)))
  quoted.vectors.df <- rbind(quoted.vectors.df, centers.df)
  quoted.vectors.matrix <- rbind(quoted.vectors.matrix, km$centers)

###############################################################################
# Run K-means again on all the tweet embedding vectors in each cluster
# to create subclusters of tweets [Done]
###############################################################################

  #EXPERIMENTAL: add the quoted and tweet matrices to get a combined representation
  #              of the original tweets and their responses at the subcluster level
  #tweet.vectors.matrix = tweet.vectors.matrix + quoted.vectors.matrix
  
  tweet.vectors.df$subcluster <- as.integer(c(0))
  quoted.vectors.df$subcluster <- as.integer(c(0))
  
  for (i in 1:k){
   cluster.matrix <- tweet.vectors.matrix[tweet.vectors.df$cluster == i,]
   if (!is.na(kmeans_subclusters_seed)) {
     set.seed(kmeans_subclusters_seed)
   }
   cluster.km <- kmeans(cluster.matrix, centers=cluster.k, iter.max=kmeans_max_iter, nstart=kmeans_nstart)
   tweet.vectors.df[tweet.vectors.df$cluster == i, "subcluster"] <- cluster.km$cluster
   quoted.vectors.df[quoted.vectors.df$cluster == i, "subcluster"] <- cluster.km$cluster
   
   #append subcluster centers to dataset for visualization
   centers.df <- data.frame(full_text=paste("Subcluster (", rownames(cluster.km$centers), ") Center", sep=""),
                           id_str="[N/A]",
                           created_at="[N/A]",
                           user_screen_name="[N/A]",
                           user_verified="[N/A]",
                           user_location="[N/A]",
                           normalized_state="[N/A]",
                           user_location_type = "[N/A]",
                           sentiment = NA,
                           vector_type = "subcluster_center",
                           cluster=as.integer(i),
                           subcluster=as.integer(rownames(cluster.km$centers)))
   tweet.vectors.df <- rbind(tweet.vectors.df, centers.df)
   tweet.vectors.matrix <- rbind(tweet.vectors.matrix, cluster.km$centers)
   quoted.vectors.df <- rbind(quoted.vectors.df, centers.df)
   quoted.vectors.matrix <- rbind(quoted.vectors.matrix, zeros(nrow(cluster.km$centers), 
                                                               ncol(cluster.km$centers)))
  }

###############################################################################
# Reorder clusters and subclusters by average sentiment [Done]
###############################################################################

  tweet.vectors.df <- order_clusters_by_avg_sentiment(tweet.vectors.df)
  #copy new assignments over to quoted df
  quoted.vectors.df$cluster <- tweet.vectors.df$cluster
  quoted.vectors.df$subcluster <- tweet.vectors.df$subcluster
  #quoted.vectors.df$sentiment <- 
  quoted.vectors.df[(nrow(results$df)+1):nrow(quoted.vectors.df), "full_text"] <- 
    tweet.vectors.df[(nrow(results$df)+1):nrow(tweet.vectors.df), "full_text"]

###############################################################################
# Compute labels for each cluster and subcluster based on word frequency
# and identify the nearest neighbors to each cluster and subcluster center
###############################################################################
  master.word_freqs <- get_word_freqs(tweet.vectors.df$full_text) %>%
    mutate(count = count / sum(count))
  master.quoted_word_freqs <- get_word_freqs(quoted.vectors.df$full_text) %>%
    mutate(count = count / sum(count))
  master.label <- get_label(master.word_freqs, top_k=master_label_top_k)
  master.quoted_label <- get_label(master.quoted_word_freqs, top_k=master_label_top_k)
  
  clusters <- list()
  for (i in 1:k) {
    cluster.df <- tweet.vectors.df[tweet.vectors.df$cluster == i,]
    cluster.matrix <- tweet.vectors.matrix[tweet.vectors.df$cluster == i,]

    cluster.word_freqs <- get_word_freqs(cluster.df$full_text) %>%
      mutate(count = count / sum(count))
    cluster.word_scores <- cluster.word_freqs %>%
      inner_join(master.word_freqs, by = "word") %>%
      mutate(score = count.x * log(count.x / count.y)) %>%
      dplyr::arrange(desc(score)) 
    cluster.label <- get_label(cluster.word_scores, master.label, top_k=cluster_label_top_k)
    cluster.center <- cluster.matrix[cluster.df$vector_type=="cluster_center",]
    cluster.nearest_center <- get_nearest_center(cluster.df, cluster.matrix, cluster.center)
    
    cluster.quoted.df <- quoted.vectors.df[quoted.vectors.df$cluster == i,]
    cluster.quoted.matrix <- quoted.vectors.matrix[quoted.vectors.df$cluster == i,]
    
    cluster.quoted_word_freqs <- get_word_freqs(cluster.quoted.df$full_text) %>%
      mutate(count = count / sum(count))
    cluster.quoted_word_scores <- cluster.quoted_word_freqs %>%
      inner_join(master.quoted_word_freqs, by = "word") %>%
      mutate(score = count.x * log(count.x / count.y)) %>%
      dplyr::arrange(desc(score)) 
    cluster.quoted_label <- get_label(cluster.quoted_word_scores, master.quoted_label, top_k=cluster_label_top_k)
    cluster.quoted_center <- cluster.quoted.matrix[cluster.quoted.df$vector_type=="cluster_center",]
    cluster.quoted_nearest_center <- get_nearest_center(cluster.quoted.df, cluster.quoted.matrix, 
                                                        cluster.quoted_center)
    
    cluster.subclusters <- list()
    for (j in 1:cluster.k) {
      subcluster.df <- cluster.df[cluster.df$subcluster == j,]
      subcluster.matrix <- cluster.matrix[cluster.df$subcluster == j,]
      
      subcluster.word_freqs <- get_word_freqs(subcluster.df$full_text) %>%
        mutate(count = count / sum(count))
      subcluster.word_scores <- subcluster.word_freqs %>%
        inner_join(cluster.word_freqs, by = "word") %>%
        mutate(score = count.x * log(count.x / count.y)) %>%
        dplyr::arrange(desc(score)) 
      subcluster.label <- get_label(subcluster.word_scores, c(master.label, cluster.label), 
                                    top_k=subcluster_label_top_k)
      subcluster.center <- subcluster.matrix[subcluster.df$vector_type=="subcluster_center",]
      subcluster.nearest_center <- get_nearest_center(subcluster.df, subcluster.matrix, subcluster.center)
      
      subcluster.quoted.df <- cluster.quoted.df[cluster.quoted.df$subcluster == j,]
      subcluster.quoted.matrix <- cluster.quoted.matrix[cluster.quoted.df$subcluster == j,]
      
      subcluster.quoted_word_freqs <- get_word_freqs(subcluster.quoted.df$full_text) %>%
        mutate(count = count / sum(count))
      subcluster.quoted_word_scores <- subcluster.quoted_word_freqs %>%
        inner_join(cluster.quoted_word_freqs, by = "word") %>%
        mutate(score = count.x * log(count.x / count.y)) %>%
        dplyr::arrange(desc(score)) 
      subcluster.quoted_label <- get_label(subcluster.quoted_word_scores, 
                                           c(master.quoted_label, cluster.quoted_label), 
                                           top_k=subcluster_label_top_k)
      subcluster.quoted_center <- subcluster.quoted.matrix[subcluster.quoted.df$vector_type=="subcluster_center",]
      subcluster.quoted_nearest_center <- get_nearest_center(subcluster.quoted.df, subcluster.quoted.matrix, 
                                                             subcluster.quoted_center)
      
      cluster.subclusters[[j]] <- list(word_freqs=subcluster.word_freqs,
                                       word_scores=subcluster.word_scores,
                                       label=subcluster.label, 
                                       nearest_center=subcluster.nearest_center,
                                       quoted_word_freqs=subcluster.quoted_word_freqs,
                                       quoted_word_scores=subcluster.quoted_word_scores,
                                       quoted_label=subcluster.quoted_label, 
                                       quoted_nearest_center=subcluster.quoted_nearest_center)
    }
    
    clusters[[i]] <- list(word_freqs=cluster.word_freqs, 
                          word_scores=cluster.word_scores,
                          label=cluster.label, 
                          nearest_center=cluster.nearest_center,
                          quoted_word_freqs=cluster.quoted_word_freqs, 
                          quoted_word_scores=cluster.quoted_word_scores,
                          quoted_label=cluster.quoted_label, 
                          quoted_nearest_center=cluster.quoted_nearest_center,
                          subclusters=cluster.subclusters)
  }

aspect1_embedding <- embed_use_large(aspect1, embedder_url)
aspect2_embedding <- embed_use_large(aspect2, embedder_url)

aspect1_cosine_similarity <- apply(tweet.vectors.matrix, 1, 
                function(v) (v %*% aspect1_embedding)/(norm(v, type="2")*norm(aspect1_embedding, type="2")))
aspect2_cosine_similarity <- apply(tweet.vectors.matrix, 1, 
                function(v) (v %*% aspect2_embedding)/(norm(v, type="2")*norm(aspect2_embedding, type="2")))

###############################################################################
# Run T-SNE on all the tweets and then again on each cluster to get
# plot coordinates for each tweet. We output a master plot with all clusters
# and a cluster plot with all subclusters for each cluster.
###############################################################################
run_tsne <- TRUE
if (run_tsne) {
  tsne_dims <- ifelse(plot_mode=="3d", 3, 2)
  tsne_coords <- c("X","Y")
  if (tsne_dims == 3) {tsne_coords <- c(tsne_coords, "Z")}
  
  if (!is.na(tsne_clusters_seed)) {
    set.seed(tsne_clusters_seed)
  }
  master.tsne <- Rtsne(tweet.vectors.matrix, dims=tsne_dims, perplexity=tsne_clusters_perplexity, 
                       max_iter=tsne_clusters_max_iter, check_duplicates=FALSE)
  master.tsne.plot <- cbind(master.tsne$Y, tweet.vectors.df)
  colnames(master.tsne.plot)[1:tsne_dims] <- tsne_coords
  master.tsne.plot$full_text <- sapply(master.tsne.plot$full_text, 
                                       function(t) paste(strwrap(t ,width=60), collapse="<br>"))
  master.tsne.plot$cluster.label <- factor(
    sapply(master.tsne.plot$cluster, function(c) format_label(clusters[[c]]$label, c)), 
    levels=sapply(1:k, function(c) format_label(clusters[[c]]$label, c)))
  
}
output_summaries_table <- exists("summaries.df") && isTRUE(show_summaries_table)
taglist <- htmltools::tagList()
#Master high level plot
taglist[[1]] <- htmltools::a(id="cluster_master")
title <- paste("Master Plot:", master.label, "(primary clusters)")
taglist[[2]] <- plot_tweets(master.tsne.plot, title=title, sentiment_threshold=sentiment_threshold,
                            type="clusters", mode=plot_mode, webGL=TRUE)
#Cluster plots
plot_index <- 3
for (i in 1:k) {
  if (run_tsne) {
    cluster.matrix <- tweet.vectors.matrix[master.tsne.plot$cluster == i,]
    
    if (!is.na(tsne_subclusters_seed)) {
      set.seed(tsne_subclusters_seed)
    }
    cluster.tsne <- Rtsne(cluster.matrix, dims=tsne_dims, perplexity=tsne_subclusters_perplexity, 
                          max_iter=tsne_subclusters_max_iter, check_duplicates=FALSE)
    cluster.tsne.plot <- cbind(cluster.tsne$Y, master.tsne.plot[master.tsne.plot$cluster == i,])
    colnames(cluster.tsne.plot)[1:tsne_dims] <- sapply(tsne_coords, function(c) paste("cluster.", c, sep=""))
    cluster.tsne.plot$subcluster.label <- factor(
      sapply(cluster.tsne.plot$subcluster, function(c) format_label(clusters[[i]]$subclusters[[c]]$label, i, c)),
      levels=sapply(1:cluster.k, function(c) format_label(clusters[[i]]$subclusters[[c]]$label, i, c)))
    clusters[[i]]$tsne.plot <- cluster.tsne.plot
  }
  
  taglist[[plot_index]] <- htmltools::a(id=format_anchor(i))
  plot_index <- plot_index + 1
  
  #Cluster plot with original positions
  if (isTRUE(show_original_subcluster_plots)) {
    title <- paste('Cluster ', i, ": ", clusters[[i]]$label, " (as positioned in master plot)")
    taglist[[plot_index]] <- plot_tweets(clusters[[i]]$tsne.plot, title=title, 
                                         sentiment_threshold=sentiment_threshold,
                                         type="subclusters_original", mode=plot_mode, webGL=FALSE)
    plot_index <- plot_index + 1
  }
  
  #Cluster plot with regrouped positions by subcluster
  if (isTRUE(show_regrouped_subcluster_plots)) {
    title <- paste('Cluster', i, ":", clusters[[i]]$label, "(regrouped by subcluster)")
    taglist[[plot_index]] <- plot_tweets(clusters[[i]]$tsne.plot, title=title, 
                                         sentiment_threshold=sentiment_threshold,
                                         type="subclusters_regrouped", mode=plot_mode, webGL=FALSE)
    plot_index <- plot_index + 1
  }
  
  # Print cluster keywords
  if (isTRUE(show_word_scores)) {
    taglist[[plot_index]] <- htmltools::HTML(kable(clusters[[i]]$word_scores[1:5,], caption=paste("Cluster", i, "word scores")) %>% kable_styling())
    plot_index <- plot_index + 1
  }
  
  # Print nearest neighbors of cluster center
  if (isTRUE(show_center_nn)) {
    taglist[[plot_index]] <- htmltools::HTML(kable(clusters[[i]]$nearest_center[1:summarize_center_nn,], caption=paste("Cluster", i, "nearest neighbors to center")) %>% kable_styling())
    plot_index <- plot_index + 1
  }
  
  for (j in 1:cluster.k) {
    # Print subcluster keywords
    if (isTRUE(show_word_scores)) {
      taglist[[plot_index]] <- htmltools::HTML(kable(clusters[[i]]$subclusters[[j]]$word_scores[1:5,], caption=paste("Subcluster", j, "word scores")) %>% kable_styling())
      plot_index <- plot_index + 1
    }
    
    # Print nearest neighbors of subcluster center
    if (isTRUE(show_center_nn)) {
      taglist[[plot_index]] <- htmltools::HTML(kable(clusters[[i]]$subclusters[[j]]$nearest_center[1:summarize_center_nn,], caption=paste("Subcluster", j, "nearest neighbors to center")) %>% kable_styling())
      plot_index <- plot_index + 1
    }
  }
  
  # navigation links
  taglist[[plot_index]] <- htmltools::a(href="#cluster_master", "Back to master plot...")
  plot_index <- plot_index + 1
  if (output_summaries_table) {
    taglist[[plot_index]] <- htmltools::br()
    plot_index <- plot_index + 1
    taglist[[plot_index]] <- htmltools::a(href="#cluster_top", "Back to top...")
    plot_index <- plot_index + 1
  }
}
  return(tweet.vectors.df,master.tsne.plot)
}

TweetSearchVersionTwo <- function(index,SemanticPhrase,Aspect1,Aspect2,RangeStart,RangeEnd,kValue,ResultSize)
{
  # Set server resource locations here:
  elasticsearch_index <- index
  elasticsearch_host <-  "lp01.idea.rpi.edu"
  elasticsearch_path <- "elasticsearch"
  elasticsearch_port <- 443
  elasticsearch_schema <- "https"
  
  embedder_url <- "http://localhost:8008/embed/use_large/"
  summarizer_url <- "http://idea-node-05:8080/batchsummarize"
  
  
  ### Configure the search parameters here:
  
  
  # query start date/time (inclusive)
  rangestart <- RangeStart
  
  # query end date/time (exclusive)
  rangeend <- RangeEnd
  
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
  semantic_phrase <- SemanticPhrase
  
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
  resultsize <- ResultSize
  
  # minimum number of results to return. This should be set according to the needs of the analysis (i.e. enough samples for statistical significance)
  min_results <- 500
  
  
  ### Configure the hyperparameters here:
  
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
  
  # number of high level clusters
  k <- kValue
  
  # number of subclusters per high level cluster
  cluster.k <- 12
  
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
  # number of nearest neighbors to the center to use for subcluster summarization
  summarize_center_nn <- 20
  
  # summarization model inference hyperparameters
  summarize_model <- "sshleifer/distilbart-xsum-12-6"
  summarize_max_len <- 60
  summarize_num_beams <- 6
  summarize_temperature <- 1.0
  
  #--------------------------
  # T-SNE HYPERPARAMS
  #--------------------------
  # hyperparams for clusters
  tsne_clusters_perplexity <- 25
  tsne_clusters_max_iter <- 1500
  
  # hyperparams for subclusters
  tsne_subclusters_perplexity <- 12
  tsne_subclusters_max_iter <- 750
  
  
  ### Configure the output settings here:
  
  
  # plot mode - '2d' or '3d'.
  # Note: if loading a snapshot, changing the plot mode will trigger T-SNE to re-run.
  plot_mode <- "2d"
  # If TRUE, cluster and subcluster summaries will be generated using nearest neighbors to the center.
  # Note: if loading a snapshot, disabling summarization will do nothing if it was previously enabled.
  summarize_clusters <- TRUE
  # True to show a listing of all cluster & subcluster summaries
  show_summaries_table <- TRUE
  # If TRUE, run and output k-means elbow plots
  # Note: if loading a snapshot, disabling elbow plots will do nothing if they were previously enabled.
  compute_elbow <- FALSE
  # If TRUE, run and output k-means silhouette plots
  # Note: if loading a snapshot, disabling silhouette plots will do nothing if they were previously enabled.
  compute_silhouette <- FALSE
  # show/hide extra info (temporary until tabs are implemented)
  show_original_subcluster_plots <- FALSE
  show_regrouped_subcluster_plots <- TRUE
  show_word_scores <- FALSE
  show_center_nn <- FALSE
  # visualize sentiment and divisiveness
  show_overall_sentiment_discrete <- TRUE
  show_overall_sentiment_map <- TRUE
  show_overall_sentiment_continuous <- FALSE
  show_cluster_sentiment_continuous <- FALSE
  show_cluster_sentiment_discrete <- TRUE
  show_cluster_divisiveness <- FALSE
  # threshold that represents the cutoff from neutral to positive above zero
  # and neutral to negative below zero. Used to turn sentiment into a variable with discrete values
  sentiment_threshold <- 0.05 # 0.05 recommended for VADER sentiment
  # sentiment plots start date (set NA to infer from search results)
  plot_range_start <- "2020-03-15"
  # sentiment plots end date (set NA to infer from search results)
  plot_range_end <- "2020-07-25"
  # perform linear regression analysis on weekly divisiveness
  perform_divisiveness_linreg <- FALSE
  
  
  ###############################################################################
  # Get the tweets from Elasticsearch using the search parameters defined above
  ###############################################################################
  
  resultfields <- '"id_str", "created_at", "user.screen_name", "user.verified", "user.location","normalized_state", "place.full_name", "place.country", "text", "full_text", "extended_tweet.full_text", "embedding.use_large.primary"'
  
  results <- do_search(indexname=elasticsearch_index, 
                       rangestart=rangestart,
                       rangeend=rangeend,
                       text_filter=text_filter,
                       location_filter=location_filter,
                       semantic_phrase=semantic_phrase,
                       must_have_embedding=TRUE,
                       must_have_geo=must_have_geo,
                       sentiment_type=sentiment_type,
                       sentiment_lower=sentiment_lower,
                       sentiment_upper=sentiment_upper,
                       random_sample=random_sample,
                       random_seed=random_seed,
                       resultsize=resultsize,
                       resultfields=resultfields,
                       elasticsearch_host=elasticsearch_host,
                       elasticsearch_path=elasticsearch_path,
                       elasticsearch_port=elasticsearch_port,
                       elasticsearch_schema=elasticsearch_schema,
                       embed_use_large_url=embedder_url)
  
  # this dataframe must contains the tweet text and other metadata.
  # validate that all necessary fields exist in the queried index and were returned:
  required_fields <- c("full_text", "id_str", "created_at", "user_screen_name", "user_verified", "user_location", "normalized_state", "place.country", "place.full_name", "sentiment")
  validate_results(results, min_results, required_fields)
  
  tweet.vectors.df <- results$df[,required_fields]
  
  # this matrix contains the embedding vectors for every tweet in tweet.vectors.df
  tweet.vectors.matrix <- t(simplify2array(results$df[,"embedding.use_large.primary"]))
  
  ###############################################################################
  # Clean the tweet and user location text, and set up tweet.vectors.df 
  # the way we want it by consolidating the location field and computing
  # location type
  ###############################################################################
  
  tweet.vectors.df$user_location <- ifelse(is.na(tweet.vectors.df$place.full_name), 
                                           tweet.vectors.df$user_location, 
                                           paste(tweet.vectors.df$place.full_name, 
                                                 tweet.vectors.df$place.country, sep=", "))
  tweet.vectors.df$user_location[is.na(tweet.vectors.df$user_location)] <- ""
  tweet.vectors.df$user_location_type <- ifelse(is.na(tweet.vectors.df$place.full_name), "User", "Place")
  tweet.vectors.df <- tweet.vectors.df[, c("id_str", "created_at", "full_text", "user_screen_name", "user_verified", "user_location", "normalized_state", "user_location_type", "sentiment")]
  
  tweet.vectors.df$full_text <- sapply(tweet.vectors.df$full_text, clean_text)
  tweet.vectors.df$user_location <- sapply(tweet.vectors.df$user_location, clean_text)
  
  ###############################################################################
  # Cleaning for HT data 
  # Clean the tweet and user location text, and set up tweet.vectors.df 
  # the way we want it by consolidating the location field and computing
  # location type
  ###############################################################################
  tweets.df <- tweet.vectors.df[!is.na(tweet.vectors.df$sentiment),]
  # test to see if Normalized State is avaible 
  tweets.df <- tweets.df[!is.na(tweets.df$normalized_state),]
  tweets.df$created_at <- as.POSIXct(strptime(tweets.df$created_at, format="%a %b %d %H:%M:%S +0000 %Y", tz="UTC"))
  tweets.df$week <- epiweek(tweets.df$created_at)  # CDC epidemiological week
  tweets.df$date <- date(tweets.df$created_at)
  tweet.tibble <- tibble(sentiment = tweets.df$sentiment, week = tweets.df$week, date = tweets.df$date, datetime = tweets.df$created_at, location = tweets.df$normalized_state  )
  summary.tibble <- tweet.tibble %>% group_by(location) %>% summarise(count = length(datetime),mean_sentiment = mean(sentiment))
  summary.tibble <- summary.tibble %>% ungroup()
  states <- states(cb=T)
  
  
  ###############################################################################
  # Run K-means on all the tweet embedding vectors
  ###############################################################################
  
  if (!is.na(kmeans_clusters_seed)) {
    set.seed(kmeans_clusters_seed)
  }
  km <- kmeans(tweet.vectors.matrix, centers=k, iter.max=kmeans_max_iter, nstart=kmeans_nstart)
  
  tweet.vectors.df$vector_type <- factor("tweet", levels=c("tweet", "cluster_center", "subcluster_center"))
  tweet.vectors.df$cluster <- km$cluster
  
  #append cluster centers to dataset for visualization
  centers.df <- data.frame(full_text=paste("Cluster (", rownames(km$centers), ") Center", sep=""),
                           id_str="[N/A]",
                           created_at="[N/A]",
                           user_screen_name="[N/A]",
                           user_verified="[N/A]",
                           user_location="[N/A]",
                           normalized_state="[N/A]",
                           user_location_type = "[N/A]",
                           sentiment = NA,
                           vector_type = "cluster_center",
                           cluster=as.integer(rownames(km$centers)))
  tweet.vectors.df <- rbind(tweet.vectors.df, centers.df)
  tweet.vectors.matrix <- rbind(tweet.vectors.matrix, km$centers)
  
  ###############################################################################
  # Run K-means again on all the tweet embedding vectors in each cluster
  # to create subclusters of tweets
  ###############################################################################
  
  tweet.vectors.df$subcluster <- as.integer(c(0))
  
  for (i in 1:k){
    cluster.matrix <- tweet.vectors.matrix[tweet.vectors.df$cluster == i,]
    if (!is.na(kmeans_subclusters_seed)) {
      set.seed(kmeans_subclusters_seed)
    }
    cluster.km <- kmeans(cluster.matrix, centers=cluster.k, iter.max=kmeans_max_iter, nstart=kmeans_nstart)
    tweet.vectors.df[tweet.vectors.df$cluster == i, "subcluster"] <- cluster.km$cluster
    
    #append subcluster centers to dataset for visualization
    centers.df <- data.frame(full_text=paste("Subcluster (", rownames(cluster.km$centers), ") Center", sep=""),
                             id_str="[N/A]",
                             created_at="[N/A]",
                             user_screen_name="[N/A]",
                             user_verified="[N/A]",
                             user_location="[N/A]",
                             normalized_state="[N/A]",
                             user_location_type = "[N/A]",
                             sentiment = NA,
                             vector_type = "subcluster_center",
                             cluster=as.integer(i),
                             subcluster=as.integer(rownames(cluster.km$centers)))
    tweet.vectors.df <- rbind(tweet.vectors.df, centers.df)
    tweet.vectors.matrix <- rbind(tweet.vectors.matrix, cluster.km$centers)
  }
  
  
  ###############################################################################
  # Reorder clusters and subclusters by average sentiment
  ###############################################################################
  
  tweet.vectors.df <- order_clusters_by_avg_sentiment(tweet.vectors.df)
  
  ###############################################################################
  # Compute labels for each cluster and subcluster based on word frequency
  # and identify the nearest neighbors to each cluster and subcluster center
  ###############################################################################
  
  master.word_freqs <- get_word_freqs(tweet.vectors.df$full_text) %>%
    mutate(count = count / sum(count))
  master.label <- get_label(master.word_freqs, top_k=master_label_top_k)
  
  clusters <- list()
  for (i in 1:k) {
    cluster.df <- tweet.vectors.df[tweet.vectors.df$cluster == i,]
    cluster.matrix <- tweet.vectors.matrix[tweet.vectors.df$cluster == i,]
    
    cluster.word_freqs <- get_word_freqs(cluster.df$full_text) %>%
      mutate(count = count / sum(count))
    cluster.word_scores <- cluster.word_freqs %>%
      inner_join(master.word_freqs, by = "word") %>%
      mutate(score = count.x * log(count.x / count.y)) %>%
      dplyr::arrange(desc(score)) 
    cluster.label <- get_label(cluster.word_scores, master.label, top_k=cluster_label_top_k)
    cluster.center <- cluster.matrix[cluster.df$vector_type=="cluster_center",]
    cluster.nearest_center <- get_nearest_center(cluster.df, cluster.matrix, cluster.center)
    
    cluster.subclusters <- list()
    for (j in 1:cluster.k) {
      subcluster.df <- cluster.df[cluster.df$subcluster == j,]
      subcluster.matrix <- cluster.matrix[cluster.df$subcluster == j,]
      
      subcluster.word_freqs <- get_word_freqs(subcluster.df$full_text) %>%
        mutate(count = count / sum(count))
      subcluster.word_scores <- subcluster.word_freqs %>%
        inner_join(cluster.word_freqs, by = "word") %>%
        mutate(score = count.x * log(count.x / count.y)) %>%
        dplyr::arrange(desc(score)) 
      subcluster.label <- get_label(subcluster.word_scores, c(master.label, cluster.label), 
                                    top_k=subcluster_label_top_k)
      subcluster.center <- subcluster.matrix[subcluster.df$vector_type=="subcluster_center",]
      subcluster.nearest_center <- get_nearest_center(subcluster.df, subcluster.matrix, subcluster.center)
      
      cluster.subclusters[[j]] <- list(word_freqs=subcluster.word_freqs,
                                       word_scores=subcluster.word_scores,
                                       label=subcluster.label, 
                                       nearest_center=subcluster.nearest_center)
    }
    
    clusters[[i]] <- list(word_freqs=cluster.word_freqs, 
                          word_scores=cluster.word_scores,
                          label=cluster.label, 
                          nearest_center=cluster.nearest_center, subclusters=cluster.subclusters)
  }
  
  ###############################################################################
  # Compute cluster and subcluster summaries using 
  # an abstractive summarization model (DistilBART)
  ###############################################################################
  # if (!exists("summaries.df") && isTRUE(summarize_clusters)) {
  #   summaries.df <- summarize_tweet_clusters(tweet.vectors.df,
  #                                            center_nn=summarize_center_nn,
  #                                            max_len=summarize_max_len,
  #                                            num_beams=summarize_num_beams,
  #                                            temperature=summarize_temperature,
  #                                            model=summarize_model,
  #                                            summarizer_url=summarizer_url)
  #   
  #   #update the cluster & subcluster center vectors' text with summaries
  #   tweet.vectors.df[rownames(summaries.df), "full_text"] <- summaries.df$summary
  #   
  #   #assign the summaries back to the cluster & subcluster lists
  #   invisible(
  #     mapply(function(vector_type, cluster, subcluster, summary) {
  #       if (vector_type == "cluster_center") {
  #         clusters[[cluster]]$summary <<- summary
  #       } else {
  #         clusters[[cluster]]$subclusters[[subcluster]]$summary <<- summary
  #       }
  #     }, summaries.df$vector_type, summaries.df$cluster, summaries.df$subcluster, summaries.df$summary))
  # }
  
  
  ###############################################################################
  # Run T-SNE on all the tweets and then again on each cluster to get
  # plot coordinates for each tweet. We output a master plot with all clusters
  # and a cluster plot with all subclusters for each cluster.
  ###############################################################################
  run_tsne <- TRUE
  if (run_tsne) {
    tsne_dims <- ifelse(plot_mode=="3d", 3, 2)
    tsne_coords <- c("X","Y")
    if (tsne_dims == 3) {tsne_coords <- c(tsne_coords, "Z")}
    
    if (!is.na(tsne_clusters_seed)) {
      set.seed(tsne_clusters_seed)
    }
    master.tsne <- Rtsne(tweet.vectors.matrix, dims=tsne_dims, perplexity=tsne_clusters_perplexity, 
                         max_iter=tsne_clusters_max_iter, check_duplicates=FALSE)
    master.tsne.plot <- cbind(master.tsne$Y, tweet.vectors.df)
    colnames(master.tsne.plot)[1:tsne_dims] <- tsne_coords
    master.tsne.plot$full_text <- sapply(master.tsne.plot$full_text, 
                                         function(t) paste(strwrap(t ,width=60), collapse="<br>"))
    master.tsne.plot$cluster.label <- factor(
      sapply(master.tsne.plot$cluster, function(c) format_label(clusters[[c]]$label, c)), 
      levels=sapply(1:k, function(c) format_label(clusters[[c]]$label, c)))
    
  }
  output_summaries_table <- exists("summaries.df") && isTRUE(show_summaries_table)
  taglist <- htmltools::tagList()
  #Master high level plot
  taglist[[1]] <- htmltools::a(id="cluster_master")
  title <- paste("Master Plot:", master.label, "(primary clusters)")
  taglist[[2]] <- plot_tweets(master.tsne.plot, title=title, sentiment_threshold=sentiment_threshold,
                              type="clusters", mode=plot_mode, webGL=TRUE)
  #Cluster plots
  plot_index <- 3
  for (i in 1:k) {
    if (run_tsne) {
      cluster.matrix <- tweet.vectors.matrix[master.tsne.plot$cluster == i,]
      
      if (!is.na(tsne_subclusters_seed)) {
        set.seed(tsne_subclusters_seed)
      }
      cluster.tsne <- Rtsne(cluster.matrix, dims=tsne_dims, perplexity=tsne_subclusters_perplexity, 
                            max_iter=tsne_subclusters_max_iter, check_duplicates=FALSE)
      cluster.tsne.plot <- cbind(cluster.tsne$Y, master.tsne.plot[master.tsne.plot$cluster == i,])
      colnames(cluster.tsne.plot)[1:tsne_dims] <- sapply(tsne_coords, function(c) paste("cluster.", c, sep=""))
      cluster.tsne.plot$subcluster.label <- factor(
        sapply(cluster.tsne.plot$subcluster, function(c) format_label(clusters[[i]]$subclusters[[c]]$label, i, c)),
        levels=sapply(1:cluster.k, function(c) format_label(clusters[[i]]$subclusters[[c]]$label, i, c)))
      clusters[[i]]$tsne.plot <- cluster.tsne.plot
    }
    
    taglist[[plot_index]] <- htmltools::a(id=format_anchor(i))
    plot_index <- plot_index + 1
    
    #Cluster plot with original positions
    if (isTRUE(show_original_subcluster_plots)) {
      title <- paste('Cluster ', i, ": ", clusters[[i]]$label, " (as positioned in master plot)")
      taglist[[plot_index]] <- plot_tweets(clusters[[i]]$tsne.plot, title=title, 
                                           sentiment_threshold=sentiment_threshold,
                                           type="subclusters_original", mode=plot_mode, webGL=FALSE)
      plot_index <- plot_index + 1
    }
    
    #Cluster plot with regrouped positions by subcluster
    if (isTRUE(show_regrouped_subcluster_plots)) {
      title <- paste('Cluster', i, ":", clusters[[i]]$label, "(regrouped by subcluster)")
      taglist[[plot_index]] <- plot_tweets(clusters[[i]]$tsne.plot, title=title, 
                                           sentiment_threshold=sentiment_threshold,
                                           type="subclusters_regrouped", mode=plot_mode, webGL=FALSE)
      plot_index <- plot_index + 1
    }
    
    # Print cluster keywords
    if (isTRUE(show_word_scores)) {
      taglist[[plot_index]] <- htmltools::HTML(kable(clusters[[i]]$word_scores[1:5,], caption=paste("Cluster", i, "word scores")) %>% kable_styling())
      plot_index <- plot_index + 1
    }
    
    # Print nearest neighbors of cluster center
    if (isTRUE(show_center_nn)) {
      taglist[[plot_index]] <- htmltools::HTML(kable(clusters[[i]]$nearest_center[1:summarize_center_nn,], caption=paste("Cluster", i, "nearest neighbors to center")) %>% kable_styling())
      plot_index <- plot_index + 1
    }
    
    for (j in 1:cluster.k) {
      # Print subcluster keywords
      if (isTRUE(show_word_scores)) {
        taglist[[plot_index]] <- htmltools::HTML(kable(clusters[[i]]$subclusters[[j]]$word_scores[1:5,], caption=paste("Subcluster", j, "word scores")) %>% kable_styling())
        plot_index <- plot_index + 1
      }
      
      # Print nearest neighbors of subcluster center
      if (isTRUE(show_center_nn)) {
        taglist[[plot_index]] <- htmltools::HTML(kable(clusters[[i]]$subclusters[[j]]$nearest_center[1:summarize_center_nn,], caption=paste("Subcluster", j, "nearest neighbors to center")) %>% kable_styling())
        plot_index <- plot_index + 1
      }
    }
    
    # navigation links
    taglist[[plot_index]] <- htmltools::a(href="#cluster_master", "Back to master plot...")
    plot_index <- plot_index + 1
    if (output_summaries_table) {
      taglist[[plot_index]] <- htmltools::br()
      plot_index <- plot_index + 1
      taglist[[plot_index]] <- htmltools::a(href="#cluster_top", "Back to top...")
      plot_index <- plot_index + 1
    }
  }
  resultList = list("tweet.vectors.df"=tweet.vectors.df,"master.tsne.plot"=master.tsne.plot)
  return(resultList)
}