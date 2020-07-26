### This set of unit tests validates that Elasticsearch.R and elasticsearch_queries.R are 
### generating syntatically valid elasticsearch query JSON for all combinations of parameters to do_search.
###
### Run these tests by executing run_tests.R.

if (!require("jsonlite")) {
  install.packages("jsonlite")
  library(jsonlite)
}

### Utility methods for unit tests

filter_na <- function(x) {
  return(x[!is.na(x)])
}

is_null_or_empty <- function(str) {
  return (is.null(str) || str == "")
}

string_or_null <- function(str) {
  return (if (str=="NULL") NULL else str)
}

get_query_node <- function(query_json) {
  if (!is.null(query_json$query$script_score)) {
    query <- query_json$query$script_score$query
  }
  else if (!is.null(query_json$query$function_score)) {
    query <- query_json$query$function_score$query
  }
  else {
    query <- query_json$query
  }
  return(query)
}

### Create grid of all possible parameter combinations that affect query generation.
### Each row of this grid represents a distinct unit test.
params.df <- expand.grid(rangestart=c("2020-04-01 00:00:00"),
                         rangeend=c("2020-04-16 00:00:00"),
                         text_filter=c('"ronon dex is a badass"', "", "NULL"),
                         location_filter=c("NY", "", "NULL"),
                         semantic_phrase=c("Harleys rock!!", "", "NULL"),
                         must_have_embedding=c(TRUE, FALSE),
                         must_have_geo=c(TRUE, FALSE),
                         random_sample=c(TRUE, FALSE),
                         resultfields=c('"created_at", "user.screen_name", "text", "full_text", "extended_tweet.full_text"'),
                         stringsAsFactors=FALSE)

### Define a test for each parameter combination
test_function <- function(params) {
  
  #unpack the parameters for this combination
  rangestart <- string_or_null(params["rangestart"])
  rangeend <- string_or_null(params["rangeend"])
  text_filter <- string_or_null(params["text_filter"])
  location_filter <- string_or_null(params["location_filter"])
  semantic_phrase <- string_or_null(params["semantic_phrase"])
  must_have_embedding <- as.logical(params["must_have_embedding"])
  must_have_geo <- as.logical(params["must_have_geo"])
  random_sample <- as.logical(params["random_sample"])
  resultfields <- string_or_null(params["resultfields"])
  
  #generate the query
  query <- do_search(rangestart=rangestart,
                     rangeend=rangeend,
                     text_filter=text_filter,
                     location_filter=location_filter,
                     semantic_phrase=semantic_phrase,
                     must_have_embedding=must_have_embedding,
                     must_have_geo=must_have_geo,
                     random_sample=random_sample,
                     resultfields=resultfields,
                     return_es_query_only=TRUE)
  
  #parse the query and locate the "query" root node
  query_json <- fromJSON(query)
  query <- get_query_node(query_json)
  
  #check common attributes - source, date range, and retweet filter should always be present.
  testthat::expect_setequal(query_json$`_source`, fromJSON(paste("[", resultfields, "]", sep="")))
  testthat::expect_equal(filter_na(query$bool$filter$range$created_at$gte), format(ymd_hms(rangestart), "%Y-%m-%dT%H:%M:%S"))
  testthat::expect_equal(filter_na(query$bool$filter$range$created_at$lt), format(ymd_hms(rangeend), "%Y-%m-%dT%H:%M:%S"))
  testthat::expect_equal(filter_na(query$bool$filter$bool$must_not$exists$field), "retweeted_status.id")
  
  #check text filter - should be present in filter if provided as a parameter and absent if not.
  if (is_null_or_empty(text_filter)) {
    testthat::expect_false(ifelse(is.null(text_filter), "", text_filter) %in% filter_na(query$bool$filter$simple_query_string$query))
  } else {
    testthat::expect_true(text_filter %in% filter_na(query$bool$filter$simple_query_string$query))
  }
  
  #check location filter - should be present in filter if provided as a parameter and absent if not.
  if (is_null_or_empty(location_filter)) {
    testthat::expect_false(ifelse(is.null(location_filter), "", location_filter) %in% filter_na(query$bool$filter$simple_query_string$query))
  } else {
    testthat::expect_true(location_filter %in% filter_na(query$bool$filter$simple_query_string$query))
  }
  
  #check semantic phrase - query should be within a script_score if provided as a parameter and not if not.
  #                        also, sort should not be present if semantic phrase is provided.
  if (is_null_or_empty(semantic_phrase)) {
    testthat::expect_null(query_json$query$script_score)
    if (isFALSE(random_sample)) {
      testthat::expect_equal(query_json$sort[1,"created_at"], "asc")
    }
  } else {
    testthat::expect_equal(query_json$query$script_score$script$source, "cosineSimilarity(params.query_vector, 'embedding.use_large.primary') + 1.0")
    testthat::expect_null(query_json$sort)
  }
  
  #check must have embedding - should be present in filter if provided as a parameter and absent if not.
  #                            NOTE: if semantic phrase is provided, this should always be present.
  if (isFALSE(must_have_embedding) && is_null_or_empty(semantic_phrase)) {
    testthat::expect_false("embedding.use_large.primary" %in% filter_na(query$bool$filter$exists$field))
  } else {
    testthat::expect_true("embedding.use_large.primary" %in% filter_na(query$bool$filter$exists$field))
  }
  
  #check must have geo - should be present in filter if provided as a parameter and absent if not.
  if (isFALSE(must_have_geo)) {
    testthat::expect_false("place.id" %in% filter_na(query$bool$filter$exists$field))
  } else {
    testthat::expect_true("place.id" %in% filter_na(query$bool$filter$exists$field))
  }
  
  #check random sample - query should be within a function_score if provided as a parameter and not if not.
  #                      also, sort should not be present if random sample is true.
  #                      NOTE: if semantic phrase is provided, random sampling should always be disabled.
  if (isFALSE(random_sample) || !is_null_or_empty(semantic_phrase)) {
    testthat::expect_null(query_json$query$function_score$random_score)
    if (is_null_or_empty(semantic_phrase)) {
      testthat::expect_equal(query_json$sort[1,"created_at"], "asc")
    }
  } else {
    testthat::expect_false(is.null(query_json$query$function_score$random_score))
    testthat::expect_null(query_json$sort)
  }
}

### Run the tests!
print(paste("Running", nrow(params.df), "tests..."))
apply(params.df, 1, test_function)
