fix_text_filter <- function(text_filter) {
  return(gsub("\"", "\\\"", text_filter, fixed=TRUE))
}

get_query_filter <- function(gte_str, lt_str, text_filter, location_filter, must_have_embedding, 
                             must_have_geo, sentiment_field, sentiment_lower, sentiment_upper) {
  if (isTRUE(must_have_embedding)) {
    embedding_clause <- '{
      "exists": { "field": "embedding.use_large.primary" }
    },'
  } else {
    embedding_clause <- ''
  }
  if (!is.null(text_filter) && text_filter != "") {
    text_query_string <- sprintf('{
      "simple_query_string": { "fields": ["text", "full_text", "extended_tweet.full_text"], "query": "%s" }
    },', fix_text_filter(text_filter))
  } else {
    text_query_string <- ''
  }
  if (!is.null(location_filter) && location_filter != "") {
    loc_query_string <- sprintf('{
      "simple_query_string": { "fields": ["place.name", "place.full_name", "place.country_code", "place.country"%s], "query": "%s" }
    },', ifelse(isFALSE(must_have_geo), ', "user.location"', ''), fix_text_filter(location_filter))
  } else {
    loc_query_string <- ''
  }
  if (isTRUE(must_have_geo)) {
    geo_clause <- '{
      "exists": { "field": "place.id" }
    },'
  } else {
    geo_clause <- ''
  }
  if(!is.null(sentiment_field) && (!is.na(sentiment_lower) || !is.na(sentiment_upper))) {
    sentiment_clause <- sprintf('{
      "range": {
            "%s": {
              %s
              %s
            }
          }
    },', sentiment_field, 
         ifelse(!is.na(sentiment_lower), sprintf('"gte": %s%s', sentiment_lower, 
                                                 ifelse(!is.na(sentiment_upper), ",", "")), ""),
         ifelse(!is.na(sentiment_upper), sprintf('"lte": %s', sentiment_upper), ""))
  } else{
    sentiment_clause <- '' 
  }
  
  filter_clause <- sprintf('{
    "bool": {
      "filter": [
        %s
        %s
        %s
        %s
        %s
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
  }', text_query_string, loc_query_string, embedding_clause, geo_clause, sentiment_clause, gte_str, lt_str)
  
  return(filter_clause)
}

base_query <- function(resultfields, gte_str, lt_str, text_filter, location_filter, must_have_embedding, 
                       must_have_geo, sentiment_field, sentiment_lower, sentiment_upper, random_sample, 
                       random_seed) {
  
  filter_clause <- get_query_filter(gte_str, lt_str, text_filter, location_filter, must_have_embedding, 
                                    must_have_geo, sentiment_field, sentiment_lower, sentiment_upper)
  
  if (isTRUE(random_sample)) {
    if (isFALSE(is.null(random_seed)) && isFALSE(is.na(random_seed))) {
      random_params <- sprintf(' "seed": %s, "field": "id_str.keyword" ', ifelse(is.character(random_seed), 
                                sprintf('"%s"', random_seed), random_seed))
    } else {
      random_params <- ''
    }
    query <- sprintf('{
       "_source": [%s],
       "query": {
         "function_score": {
            "query": %s,
            "random_score": {%s},
            "boost_mode": "replace"
         }
      }
    }', resultfields, filter_clause, random_params)
  } else {
    query <- sprintf('{
      "sort" : [
        { "created_at" : "asc" }
      ],
      "_source": [%s],
      "query": %s
    }', resultfields, filter_clause)
  }
  
  return(query)
}

semantic_query <- function(resultfields, gte_str, lt_str, text_filter, location_filter, must_have_geo, 
                           sentiment_field, sentiment_lower, sentiment_upper, text_embedding) {
  
  filter_clause <- get_query_filter(gte_str, lt_str, text_filter, location_filter, TRUE, must_have_geo,
                                    sentiment_field, sentiment_lower, sentiment_upper)
  
  query <- sprintf('{
    "_source": [%s],
    "query": {
      "script_score": {
        "query": %s,
        "script": {
          "source": "cosineSimilarity(params.query_vector, \'embedding.use_large.primary\') + 1.0",
          "params": {"query_vector": %s}
        }
      }
    }
  }', resultfields, filter_clause, text_embedding)
  
  return(query)
}
