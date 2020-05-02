
if (!require("elastic")) {
  install.packages("elastic")
  library(elastic)
}

if (!require("lubridate")) {
  install.packages("lubridate")
  library(lubridate)
}

if (!require("httr")) {
  install.packages("httr")
  library(httr)
}

if (!require("jsonlite")) {
  install.packages("jsonlite")
  library(jsonlite)
}

source("elasticsearch_queries.R")

embed_use_large <- function(text, embed_use_large_url) {
  req <- paste(embed_use_large_url, URLencode(text, reserved=TRUE), sep="")
  res <- GET(req)
  res.text <- content(res, "text", encoding="UTF-8")
  res.json <- fromJSON(res.text)
  text_embedding <- res.json$use_large
}

do_search <- function(indexname, 
                      rangestart, # query start date/time (inclusive)
                      rangeend,   # query end date/time (exclusive)
                      semantic_phrase="",
                      must_have_embedding=FALSE,
                      random_sample=FALSE,
                      resultsize=10,
                      resultfields=NULL,
                      elasticsearch_host="localhost",
                      elasticsearch_path="",
                      elasticsearch_port=9200,
                      elasticsearch_schema="http",
                      embed_use_large_url="http://localhost:8008/embed/use_large/") {

  #Validate params
  
  if (missing(indexname)) { stop("indexname not specified.") }
  
  if (missing(rangestart) || missing(rangeend)) { stop("rangestart and rangeend not specified.") }
  rangestart <- ymd_hms(rangestart)
  rangeend <- ymd_hms(rangeend)
  
  if (is.null(resultfields)) {
    resultfields <- '"created_at", "user.id_str", "user.screen_name",
            "in_reply_to_status_id_str", "favorite_count", "text", "extended_tweet.full_text",
            "source", "retweeted", "in_reply_to_screen_name", "in_reply_to_user_id_str",
            "retweet_count", "favorited", "entities.hashtags", "extended_tweet.entities.hashtags",
            "entities.urls", "extended_tweet.entities.urls"'
  }
   
  #Do the search
  conn <- connect(host = elasticsearch_host,
                  path = elasticsearch_path, 
                  port = elasticsearch_port, 
                  transport_schema = elasticsearch_schema,
                  errors="complete")
  
  gte_str <- format(rangestart, "%Y-%m-%dT%H:%M:%S")
  lt_str <- format(rangeend, "%Y-%m-%dT%H:%M:%S")
  
  if (semantic_phrase == "") {
    query <- query_by_date_range(resultfields, gte_str, lt_str, must_have_embedding, random_sample)
  } else {
    text_embedding <- embed_use_large(semantic_phrase, embed_use_large_url)
    query <- query_by_date_range_and_embedding(resultfields, gte_str, lt_str, toJSON(text_embedding))
  }
  #print(query)
  
  results <- Search(conn, index=indexname, body=query, size=resultsize, asdf=TRUE)
  results.total <- results$hits$total$value
  results.df <- results$hits$hits[,3:ncol(results$hits$hits)]
  
  #fix score for semantic search
  if (semantic_phrase != "") {
    results.df$`_score` <- results.df$`_score` - 1.0
    colnames(results.df) <- sub("_score", "cosine_similarity", colnames(results.df))
  }
  
  #fix column names
  colnames(results.df) <- sub("_source.", "", colnames(results.df))
  colnames(results.df) <- sub("extended_tweet.entities.", "extended_tweet.entities.full_", colnames(results.df))
  colnames(results.df) <- sub("extended_tweet.", "", colnames(results.df))
  colnames(results.df) <- sub("entities.", "", colnames(results.df))
  colnames(results.df) <- sub("user.", "user_", colnames(results.df))
  #merge 'text' and 'full_text'
  if ("full_text" %in% colnames(results.df)) {
    results.df$full_text <- ifelse(is.na(results.df$full_text), results.df$text, results.df$full_text)
  } else {
    results.df$full_text <- results.df$text
  }
  
  #TODO: drop original 'text' column
  #TODO: merge 'hashtags' and 'full_hashtags', merge 'urls' and 'full_urls'
  #TODO: drop original 'hashtags' and 'urls' columns
  
  return(list(total=results.total, 
              df=results.df,
              params=list(
                rangestart=rangestart,
                rangeend=rangeend,
                semantic_phrase=semantic_phrase
              )))
}