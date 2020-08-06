source("Elasticsearch.R")

# number of results to return (to return all results, set to NA)
resultsize <- NA

# raw JSON elasticsearch query
query <- '{
  "_source": ["place.name", "place.full_name", "place.place_type", "place.country_code", "place.country"],
  "query": {
    "bool": {
      "filter": [
        {
          "simple_query_string": {
            "fields": ["place.country_code"],
            "query": "US"
          }
        },
        {
          "simple_query_string": {
            "fields": ["place.place_type"],
            "query": "admin city"
          }
        }
      ]
    }
  },
  "aggs": {
    "states": {
      "terms": {
        "field": "place.name.keyword"
      }
    }
  }
}'

results <- do_search_raw(indexname="coronavirus-data-masks", 
                         query,
                         resultsize=resultsize,
                         elasticsearch_host="",
                         elasticsearch_path="elasticsearch",
                         elasticsearch_port=443,
                         elasticsearch_schema="https")

print(paste(nrow(results$hits$hits), "/", results$hits$total$value))