
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

if (!require("dplyr")) {
  install.packages("dplyr")
  library(dplyr)
}


source("elasticsearch_queries.R")

embed_use_large <- function(text, embed_use_large_url) {
  req <- paste(embed_use_large_url, URLencode(text, reserved=TRUE), sep="")
  res <- GET(req)
  res.text <- content(res, "text", encoding="UTF-8")
  res.json <- fromJSON(res.text)
  text_embedding <- res.json$use_large
}

do_search_raw <- function(indexname, 
                          query, 
                          resultsize=10, 
                          elasticsearch_host="localhost",
                          elasticsearch_path="",
                          elasticsearch_port=9200,
                          elasticsearch_schema="http") {
  
  if (isTRUE(is.na(resultsize)) || isTRUE(resultsize < 0)) {
    #all results, unlimited size.
    resultsize <- NULL
  }
  
  conn <- connect(host = elasticsearch_host,
                  path = elasticsearch_path, 
                  port = elasticsearch_port, 
                  transport_schema = elasticsearch_schema,
                  errors="complete")
  
  max_res_window <- 10000
  #If the requested result size exceeds the max result window, use scrolling.
  #Othewrwise, a standard search call is made.
  if (is.null(resultsize) || resultsize > max_res_window) {
    scroll_id <- NULL
    results <- tryCatch({
      
      #Do initial search to open a scroll window
      first_results <- Search(conn, index=indexname, body=query, size=max_res_window, asdf=TRUE, time_scroll="5m")
      scroll_id <- first_results$`_scroll_id`
      has_results <- is.data.frame(first_results$hits$hits)
      
      #If we have results, proceed to iteratively scroll through them
      if (has_results) {
        scroll_results_list = list(first_results$hits$hits)
        scroll_i <- 2
        scroll_result_count <- nrow(first_results$hits$hits)
        
        while (has_results) {
          scroll_results <- scroll(conn, scroll_id, asdf=TRUE, time_scroll="5m")
          scroll_id <- scroll_results$`_scroll_id`
          has_results <- is.data.frame(scroll_results$hits$hits)
          
          if (has_results) {
            #For every iteration, add the results to the list
            scroll_result_count <- scroll_result_count + nrow(scroll_results$hits$hits)
            
            #Check if we have reached the desired number of results. 
            #If so, stop scrolling even though there may be more results that can be retrieved.
            if (!is.null(resultsize) && scroll_result_count >= resultsize) {
              take <- resultsize - scroll_result_count + nrow(scroll_results$hits$hits)
              scroll_results_list[[scroll_i]] <- scroll_results$hits$hits[1:take,]
              break
            } else {
              scroll_results_list[[scroll_i]] <- scroll_results$hits$hits
              scroll_i <- scroll_i + 1
            }
          }
        }
        #If scroll_results_list is not empty, combine all the results now
        if (length(scroll_results_list) > 1) {
          first_results$hits$hits <- bind_rows(scroll_results_list)
        }
      }
      first_results
    },
    finally={
      #Must dispose of the search context, otherwise it will hog memory until the time limit expires!
      if (!is.null(scroll_id)) {
        scroll_clear(conn, scroll_id)
      }
    })
  } else {
    results <- Search(conn, index=indexname, body=query, size=resultsize, asdf=TRUE)
  }
  return(results)
}

do_search <- function(indexname, 
                      rangestart, # query start date/time (inclusive)
                      rangeend,   # query end date/time (exclusive)
                      text_filter="",
                      location_filter="",
                      semantic_phrase="",
                      must_have_embedding=FALSE,
                      must_have_geo=FALSE,
                      sentiment_type="",
                      sentiment_lower=NA,
                      sentiment_upper=NA,
                      random_sample=FALSE,
                      random_seed=NA,
                      resultsize=10,
                      resultfields="",
                      elasticsearch_host="localhost",
                      elasticsearch_path="",
                      elasticsearch_port=9200,
                      elasticsearch_schema="http",
                      embed_use_large_url="http://localhost:8008/embed/use_large/",
                      return_es_query_only=FALSE) {

  #Validate params
  
  if (missing(indexname) && isFALSE(return_es_query_only)) { stop("indexname not specified.") }
  
  if (missing(rangestart) || missing(rangeend)) { stop("rangestart and rangeend not specified.") }
  rangestart <- ymd_hms(rangestart)
  rangeend <- ymd_hms(rangeend)

  if (is.null(resultfields) || resultfields=="") {
    resultfields <- '"created_at", "user.id_str", "user.screen_name",
            "in_reply_to_status_id_str", "favorite_count", "text", "full_text", "extended_tweet.full_text",
            "source", "retweeted", "in_reply_to_screen_name", "in_reply_to_user_id_str",
            "retweet_count", "favorited", "entities.hashtags", "extended_tweet.entities.hashtags",
            "entities.urls", "extended_tweet.entities.urls"'
  }
  
  sentiment_field <- NULL
  if (!is.null(sentiment_type) && sentiment_type != "") {
    sentiment_field <- paste("sentiment.", sentiment_type, ".primary", sep="")
    resultfields <- paste(resultfields, ', "', sentiment_field, '"', sep="")
  }
  
  #Do the search
  gte_str <- format(rangestart, "%Y-%m-%dT%H:%M:%S")
  lt_str <- format(rangeend, "%Y-%m-%dT%H:%M:%S")
  
  if (is.null(semantic_phrase) || semantic_phrase == "") {
    query <- base_query(resultfields, 
                        gte_str, 
                        lt_str, 
                        text_filter, 
                        location_filter, 
                        must_have_embedding, 
                        must_have_geo,
                        sentiment_field,
                        sentiment_lower,
                        sentiment_upper,
                        random_sample,
                        random_seed)
  } else {
    text_embedding <- embed_use_large(semantic_phrase, embed_use_large_url)
    query <- semantic_query(resultfields,
                            gte_str,
                            lt_str,
                            text_filter,
                            location_filter,
                            must_have_geo,
                            sentiment_field,
                            sentiment_lower,
                            sentiment_upper,
                            toJSON(text_embedding))
  }
  
  if (isTRUE(return_es_query_only)) {
    return(query)
  }
  
  results <- do_search_raw(indexname, 
                           query, 
                           resultsize, 
                           elasticsearch_host, 
                           elasticsearch_path, 
                           elasticsearch_port, 
                           elasticsearch_schema)
  
  results.total <- results$hits$total$value
  results.df <- NULL
  
  if (results.total > 0) {
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
    if (!is.null(sentiment_field)) {
      if (sentiment_field %in% colnames(results.df)) {
        colnames(results.df)[colnames(results.df) == sentiment_field] <- "sentiment"
      } else {
        results.df$sentiment <- NA
      }
    }
    
    #merge 'text' and 'full_text'
    if ("text" %in% colnames(results.df)) {
      if ("full_text" %in% colnames(results.df)) {
        results.df$full_text <- ifelse(is.na(results.df$full_text), results.df$text, results.df$full_text)
      } else {
        results.df$full_text <- results.df$text
      }
    }
    
    #TODO: drop original 'text' column
    #TODO: merge 'hashtags' and 'full_hashtags', merge 'urls' and 'full_urls'
    #TODO: drop original 'hashtags' and 'urls' columns
  }
  
  return(list(total=results.total, 
              df=results.df,
              params=list(
                rangestart=rangestart,
                rangeend=rangeend,
                text_filter=text_filter,
                location_filter=location_filter,
                semantic_phrase=semantic_phrase,
                must_have_geo=must_have_geo
              )))
}

validate_results <- function(df, min_results, required_fields=character(0)) {
  # check for minimum results
  if (results$total < min_results) {
    stop(paste("Insufficient results found for the provided search parameters - ", 
               results$total, " result(s) were found and ", min_results, " result(s) are required. Try expanding your search.", sep=""))
  }
  
  # check for required fields
  missing_fields <- setdiff(required_fields, colnames(df))
  if (length(missing_fields) > 0) {
    stop(paste("The results found for the provided search parameters are missing the following required field(s): ", 
               paste(missing_fields, collapse=", "), ". Try expanding your search.", sep=""))
  }
}