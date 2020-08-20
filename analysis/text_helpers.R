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
  word_freqs <- cbind.data.frame(names(word_freqs), as.integer(word_freqs))
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
