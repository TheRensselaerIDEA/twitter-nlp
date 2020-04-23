query_by_date_range <- function(resultfields, gte_str, lt_str) {
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
  
  return(query)
}

query_by_date_range_and_embedding <- function(resultfields, gte_str, lt_str, text_embedding) {
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
          "source": "cosineSimilarity(params.query_vector, \'embedding.use_large.primary\') + 1.0",
          "params": {"query_vector": %s}
        }
      }
    }
  }', resultfields, gte_str, lt_str, text_embedding)
  
  return(query)
}
