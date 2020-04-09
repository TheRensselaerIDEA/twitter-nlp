
if (!require("elastic")) {
  install.packages("elastic")
  library(elastic)
}

if (!require("lubridate")) {
  install.packages("lubridate")
  library(lubridate)
}

########################################################################################
# Demo script for querying a dataframe of twitter data from Elasticsearch by date range.
# Configure here and run!

# URL to Elasticsearch instance
ideavmelasticsearch <- "http://localhost:9200"

# Elasticsearch index name
indexname <- "coronavirus-data2"

# query start date/time (inclusive)
rangestart <- ymd_hms("2020-04-08 00:00:00")

# query end date/time (exclusive)
rangeend <- ymd_hms("2020-04-08 01:00:00")

# number of results to return (max 10,000)
resultsize <- 50

# fields to include in results
resultfields <- '"id_str", "created_at", "user.id_str", "user.screen_name",
            "in_reply_to_status_id_str", "favorite_count", "text", "extended_tweet.full_text",
            "source", "retweeted", "in_reply_to_screen_name", "in_reply_to_user_id_str",
            "retweet_count", "favorited", "entities.hashtags", "extended_tweet.entities.hashtags",
            "entities.urls", "extended_tweet.entities.urls"'

########################################################################################

conn <- connect(es_host = ideavmelasticsearch,
        es_path = "", 
        es_port = 443, 
        es_transport_schema = "https",
        errors="complete")

gte_str = format(rangestart, "%Y-%m-%dT%H:%M:%S")
lt_str = format(rangeend, "%Y-%m-%dT%H:%M:%S")

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

results <- Search(conn, index=indexname, body=query, size=resultsize, asdf=TRUE)
results.total <- results$hits$total$value
results.df <- results$hits$hits[,6:ncol(results$hits$hits)]
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
