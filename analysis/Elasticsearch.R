
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

########################################################################################
# Demo script for querying a dataframe of twitter data from Elasticsearch by date range
# and semantic similarity phrase.
# Configure here and run!

# Embedding server info
embed_use_large_url <- "http://localhost:8080/embed/use_large/"

# Elasticsearch instance info
elasticsearch_host <- ""
elasticsearch_path <- "elasticsearch"
elasticsearch_port <- 443
elasticsearch_schema <- "https"

# Elasticsearch index name
indexname <- "coronavirus-data-all"

# query start date/time (inclusive)
rangestart <- ymd_hms("2020-03-18 00:00:00")

# query end date/time (exclusive)
rangeend <- ymd_hms("2020-03-19 00:00:00")

# query semantic similarity phrase
semantic_phrase <- ""

# number of results to return (max 10,000)
resultsize <- 50

# fields to include in results
resultfields <- '"id_str", "created_at", "user.id_str", "user.screen_name",
            "in_reply_to_status_id_str", "favorite_count", "text", "extended_tweet.full_text",
            "source", "retweeted", "in_reply_to_screen_name", "in_reply_to_user_id_str",
            "retweet_count", "favorited", "entities.hashtags", "extended_tweet.entities.hashtags",
            "entities.urls", "extended_tweet.entities.urls"'

########################################################################################

embed_use_large <- function(text) {
  req <- paste(embed_use_large_url, URLencode(text, reserved=TRUE), sep="")
  res <- GET(req)
  res.text <- content(res, "text", encoding="UTF-8")
  res.json <- fromJSON(res.text)
  text_embedding <- res.json$use_large
}

conn <- connect(host = elasticsearch_host,
                path = elasticsearch_path, 
                port = elasticsearch_port, 
                transport_schema = elasticsearch_schema,
                errors="complete")

gte_str = format(rangestart, "%Y-%m-%dT%H:%M:%S")
lt_str = format(rangeend, "%Y-%m-%dT%H:%M:%S")

if (semantic_phrase == "") {
  query <- sprintf('{
    "sort" : [
      { "created_at" : "asc" }
    ],
    "_source": [%s],
    "query": {
      "bool": {
        "filter": [
          {
            "range" : {
              "created_at" : {
                "gte": "%s",
                "lt": "%s",
                "format": "strict_date_hour_minute_second",
                "time_zone": "+00:00"
              }
            }
          },
          {
            "bool": {
              "must_not": {
                "exists": {
                  "field": "retweeted_status.id"
                }
              }
            }
          }
        ]
      }
    }
  }', resultfields, gte_str, lt_str)
} else {
  text_embedding <- embed_use_large(semantic_phrase)
  query <- sprintf('{
    "_source": [%s],
    "query": {
      "script_score": {
        "query": {
          "bool": {
            "filter": [
              {
                "range" : {
                  "created_at" : {
                    "gte": "%s",
                    "lt": "%s",
                    "format": "strict_date_hour_minute_second",
                    "time_zone": "+00:00"
                  }
                }
              },
              {
                "exists": { "field": "embedding.use_large.primary" }
              }
            ]
          }
        },
        "script": {
          "source": "cosineSimilarity(params.query_vector, doc[\'embedding.use_large.primary\']) + 1.0",
          "params": {"query_vector": %s}
        }
      }
    }
  }', resultfields, gte_str, lt_str, toJSON(text_embedding))
}

results <- Search(conn, index=indexname, body=query, size=resultsize, asdf=TRUE)
results.total <- results$hits$total$value
results.df <- results$hits$hits[,c(4, 6:ncol(results$hits$hits))]

#fix score for semantic search
if (semantic_phrase != "") {
  results.df$`_score` <- results.df$`_score` - 1.0
  colnames(results.df)[1] <- "cosine_similarity"
}

#fix column names
colnames(results.df) <- sub("_source.", "", colnames(results.df))
colnames(results.df) <- sub("extended_tweet.entities.", "extended_tweet.entities.full_", colnames(results.df))
colnames(results.df) <- sub("extended_tweet.", "", colnames(results.df))
colnames(results.df) <- sub("entities.", "", colnames(results.df))
colnames(results.df) <- sub("user.", "user_", colnames(results.df))
#merge 'text' and 'full_text'
results.df$full_text <- ifelse(is.na(results.df$full_text), results.df$text, results.df$full_text)

#TODO: drop original 'text' column
#TODO: merge 'hashtags' and 'full_hashtags', merge 'urls' and 'full_urls'
#TODO: drop original 'hashtags' and 'urls' columns
