################################################################
# Helper functions for cleaning and analyzing text in the context
# of clustered tweets.
################################################################

if(!require('stringr')) {
  install.packages("stringr")
  library(stringr)
}

if(!require('stopwords')) {
  install.packages("stopwords")
  library(stopwords)
}

if(!require('dplyr')) {
  install.packages("dplyr")
  library(dplyr)
}

if (!require("kableExtra")) {
  install.packages("kableExtra")
  library(kableExtra)
}

stop_words <- stopwords("en", source="snowball")
stop_words <- union(stop_words, stopwords("en", source="nltk"))
stop_words <- union(stop_words, stopwords("en", source="smart"))
stop_words <- union(stop_words, stopwords("en", source="marimo"))
stop_words <- union(stop_words, c(",", ".", "!", "-", "?", "&amp;", "amp"))

################################################################
# Cleans text of undesired characters. 
# - For word frequency analysis, all non-alphanumeric are removed.
# - Otherwise most common punctuation is allowed.
################################################################
clean_text <- function(text, for_freq=FALSE) {
  text <- str_replace_all(text, "[\\s]+", " ")
  text <- str_replace_all(text, "http\\S+", "")
  if (isTRUE(for_freq)) {
    text <- tolower(text)
    text <- str_replace_all(text, "’", "'")
    text <- str_replace_all(text, "_", "-")
    text <- str_replace_all(text, "[^a-z1-9 ']", "")
  } else {
    text <- str_replace_all(text, "[^a-zA-Z1-9 `~!@#$%^&*()-_=+\\[\\];:'\",./?’]", "")
  }
  text <- str_replace_all(text, " +", " ")
  text <- trimws(text)
}

################################################################
# Returns a table of non-stopword word frequencies 
# in descending order (most frequent word first).
################################################################
get_word_freqs <- function(full_text) {
  word_freqs <- table(unlist(strsplit(clean_text(full_text, TRUE), " ")))
  word_freqs <- cbind.data.frame(names(word_freqs), as.integer(word_freqs), stringsAsFactors=FALSE)
  colnames(word_freqs) <- c("word", "count")
  word_freqs <- word_freqs[!(word_freqs$word %in% stop_words),]
  word_freqs <- word_freqs[order(word_freqs$count, decreasing=TRUE),]
}

################################################################
# Constructs a label from the top k most frequent words,
# separated by a '/'. This is used to label clusters and subclusters.
################################################################
get_label <- function(word_freqs, exclude_from_labels=NULL, top_k=3) {
  words <- as.character(word_freqs$word)
  exclude_words <- NULL
  if (!is.null(exclude_from_labels)) {
    exclude_words <- unique(unlist(lapply(strsplit(exclude_from_labels, "/"), trimws)))
  }
  label <- paste(setdiff(words, exclude_words)[1:top_k], collapse=" / ")
}

################################################################
# Formats cluster or subcluster labels and anchors for display
################################################################
format_label <- function(label, cluster, subcluster=NULL, include_prefix=FALSE) {
  if (is.null(subcluster) || is.na(subcluster)) {
    paste0(ifelse(isTRUE(include_prefix), "Cluster ", ""), cluster, ". ", label)
  } else {
    paste0(ifelse(isTRUE(include_prefix), ".........", ""), cluster, ".", subcluster, ". ", label)
  }
}

format_anchor <- function(cluster, subcluster=NULL, include_pound=FALSE) {
  if (is.null(subcluster) || is.na(subcluster)) {
    paste0(ifelse(isTRUE(include_pound), "#", ""), "cluster_", cluster)
  } else {
    paste0(ifelse(isTRUE(include_pound), "#", ""), "subcluster_", cluster, "_", subcluster)
  }
}

################################################################
# Orders a list of tweet metadata by cosine similarity to a 
# cluster or subcluster center in descending order (closest first).
################################################################
get_nearest_center <- function(df, mtx, center) {
  df$center_cosine_similarity <- apply(mtx, 1, function(v) (v %*% center)/(norm(v, type="2")*norm(center, type="2")))
  nearest_center <- df[order(df$center_cosine_similarity, decreasing=TRUE),]
  nearest_center <- nearest_center[nearest_center$vector_type=="tweet", c("center_cosine_similarity", "full_text", "user_location")]
}

################################################################
# Concatenates the text of the top k nearest neighbor tweets 
# to create the input "document" for the text summarization model.
################################################################
concat_text_for_summary <- function(nearest_center, k_nn) {
  summary <- paste('"', paste(nearest_center[1:min(k_nn, nrow(nearest_center)), "full_text"], collapse='" "'), '"', sep="")
}


################################################################
# Formats the cluster & subcluster summaries listing
################################################################
format_summaries_table <- function(summaries.df) {
  summaries_table.df <- summaries.df %>% 
    arrange(cluster, vector_type, subcluster)
  
  summaries_table.df[summaries_table.df$vector_type=="cluster_center", "subcluster"] <- NA
  
  summaries_table.df$label <- mapply(function(cluster, subcluster) {
    label <- if (is.na(subcluster)) {clusters[[cluster]]$label} 
    else  {clusters[[cluster]]$subclusters[[subcluster]]$label}
    return (format_label(label, cluster, subcluster, include_prefix=TRUE))
  }, summaries_table.df$cluster, summaries_table.df$subcluster)
  
  summaries_table.df$href <- sapply(summaries_table.df$cluster, function(cluster) {
    return(format_anchor(cluster, include_pound=TRUE))
  })
  
  summaries_table.df <- summaries_table.df %>%
    mutate(label = cell_spec(label, "html", link = href))
  
  summaries_table.df <- summaries_table.df[, c("label", "summary")]
  return (summaries_table.df)
}
