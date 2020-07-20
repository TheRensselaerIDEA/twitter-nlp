### This set of unit tests validates that Elasticsearch.R and elasticsearch_queries.R are 
### generating syntatically valid elasticsearch query JSON for all combinations of parameters to do_search.
###
### Run these tests by executing run_tests.R.

if (!require("jsonlite")) {
  install.packages("jsonlite")
  library(jsonlite)
}

###Utility methods for unit tests

filter_na <- function(x) {
  return(x[!is.na(x)])
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

test_common <- function(query_json) {
  query <- get_query_node(query_json)
  testthat::expect_equal(query_json$`_source`[[1]], "created_at")
  testthat::expect_equal(filter_na(query$bool$filter$range$created_at$gte), "2020-04-01T00:00:00")
  testthat::expect_equal(filter_na(query$bool$filter$range$created_at$lt), "2020-04-16T00:00:00")
}

test_random_sample <- function(query_json) {
  testthat::expect_false(is.null(query_json$query$function_score$random_score))
  testthat::expect_null(query_json$sort)
}

test_not_random_sample <- function(query_json) {
  testthat::expect_null(query_json$query$function_score$random_score)
  if (is.null(query_json$query$script_score)) {
    testthat::expect_equal(query_json$sort[1,"created_at"], "asc")
  }
}

test_must_have_embedding <- function(query_json) {
  query <- get_query_node(query_json)
  testthat::expect_equal(filter_na(query$bool$filter$exists$field), "embedding.use_large.primary")
}

test_not_must_have_embedding <- function(query_json) {
  query <- get_query_node(query_json)
  testthat::expect_null(query$bool$filter$exists$field)
  testthat::expect_equal(filter_na(query$bool$filter$bool$must_not$exists$field), "retweeted_status.id")
}

test_text_filter <- function(query_json) {
  query <- get_query_node(query_json)
  testthat::expect_equal(filter_na(query$bool$filter$simple_query_string$query), '"ronon dex is a badass"')
}

test_not_text_filter <- function(query_json) {
  query <- get_query_node(query_json)
  testthat::expect_null(query$bool$filter$simple_query_string)
}

test_semantic_phrase <- function(query_json) {
  testthat::expect_equal(query_json$query$script_score$script$source, "cosineSimilarity(params.query_vector, 'embedding.use_large.primary') + 1.0")
  testthat::expect_null(query_json$sort)
}

test_not_semantic_phrase <- function(query_json) {
  testthat::expect_null(query_json$query$script_score)
  if (is.null(query_json$query$function_score)) {
    testthat::expect_equal(query_json$sort[1,"created_at"], "asc")
  }
}

###Unit test definitions
rangestart <- "2020-04-01 00:00:00"
rangeend <- "2020-04-16 00:00:00"
text_filter <- '"ronon dex is a badass"'
semantic_phrase <- "Harleys rock!!"
resultfields <- '"created_at", "user.screen_name", "text", "full_text", "extended_tweet.full_text"'

###############################################################
## Test block 1: combinations for base (non-semantic) search ##
###############################################################

##################################################################################################

testthat::test_that("Test base query", {
  query <- do_search(rangestart=rangestart,
                     rangeend=rangeend,
                     text_filter="",
                     semantic_phrase="",
                     must_have_embedding=FALSE,
                     random_sample=FALSE,
                     resultfields=resultfields,
                     return_es_query_only=TRUE)
  
  query_json <- fromJSON(query)
  test_common(query_json)
  test_not_random_sample(query_json)
  test_not_must_have_embedding(query_json)
  test_not_text_filter(query_json)
  test_not_semantic_phrase(query_json)
})

##################################################################################################

testthat::test_that("Test base query + must have embeddings", {
  query <- do_search(rangestart=rangestart,
                     rangeend=rangeend,
                     text_filter="",
                     semantic_phrase="",
                     must_have_embedding=TRUE,
                     random_sample=FALSE,
                     resultfields=resultfields,
                     return_es_query_only=TRUE)
  
  query_json <- fromJSON(query)
  test_common(query_json)
  test_not_random_sample(query_json)
  test_must_have_embedding(query_json)
  test_not_text_filter(query_json)
  test_not_semantic_phrase(query_json)
})

##################################################################################################

testthat::test_that("Test base query + random sample", {
  query <- do_search(rangestart=rangestart,
                     rangeend=rangeend,
                     text_filter="",
                     semantic_phrase="",
                     must_have_embedding=FALSE,
                     random_sample=TRUE,
                     resultfields=resultfields,
                     return_es_query_only=TRUE)
  
  query_json <- fromJSON(query)
  test_common(query_json)
  test_random_sample(query_json)
  test_not_must_have_embedding(query_json)
  test_not_text_filter(query_json)
  test_not_semantic_phrase(query_json)
})

##################################################################################################

testthat::test_that("Test base query + text filter", {
  query <- do_search(rangestart=rangestart,
                     rangeend=rangeend,
                     text_filter=text_filter,
                     semantic_phrase="",
                     must_have_embedding=FALSE,
                     random_sample=FALSE,
                     resultfields=resultfields,
                     return_es_query_only=TRUE)
  
  query_json <- fromJSON(query)
  test_common(query_json)
  test_not_random_sample(query_json)
  test_not_must_have_embedding(query_json)
  test_text_filter(query_json)
  test_not_semantic_phrase(query_json)
})

##################################################################################################

testthat::test_that("Test base query + must have embeddings + random sample", {
  query <- do_search(rangestart=rangestart,
                     rangeend=rangeend,
                     text_filter="",
                     semantic_phrase="",
                     must_have_embedding=TRUE,
                     random_sample=TRUE,
                     resultfields=resultfields,
                     return_es_query_only=TRUE)
  
  query_json <- fromJSON(query)
  test_common(query_json)
  test_random_sample(query_json)
  test_must_have_embedding(query_json)
  test_not_text_filter(query_json)
  test_not_semantic_phrase(query_json)
})

##################################################################################################

testthat::test_that("Test base query + must have embeddings + text filter", {
  query <- do_search(rangestart=rangestart,
                     rangeend=rangeend,
                     text_filter=text_filter,
                     semantic_phrase="",
                     must_have_embedding=TRUE,
                     random_sample=FALSE,
                     resultfields=resultfields,
                     return_es_query_only=TRUE)
  
  query_json <- fromJSON(query)
  test_common(query_json)
  test_not_random_sample(query_json)
  test_must_have_embedding(query_json)
  test_text_filter(query_json)
  test_not_semantic_phrase(query_json)
})

##################################################################################################

testthat::test_that("Test base query + random sample + text filter", {
  query <- do_search(rangestart=rangestart,
                     rangeend=rangeend,
                     text_filter=text_filter,
                     semantic_phrase="",
                     must_have_embedding=FALSE,
                     random_sample=TRUE,
                     resultfields=resultfields,
                     return_es_query_only=TRUE)
  
  query_json <- fromJSON(query)
  test_common(query_json)
  test_random_sample(query_json)
  test_not_must_have_embedding(query_json)
  test_text_filter(query_json)
  test_not_semantic_phrase(query_json)
})

##################################################################################################

testthat::test_that("Test base query + must have embeddings + random sample + text filter", {
  query <- do_search(rangestart=rangestart,
                     rangeend=rangeend,
                     text_filter=text_filter,
                     semantic_phrase="",
                     must_have_embedding=TRUE,
                     random_sample=TRUE,
                     resultfields=resultfields,
                     return_es_query_only=TRUE)
  
  query_json <- fromJSON(query)
  test_common(query_json)
  test_random_sample(query_json)
  test_must_have_embedding(query_json)
  test_text_filter(query_json)
  test_not_semantic_phrase(query_json)
})

##################################################################################################

####################################################
## Test block 2: combinations for semantic search ##
####################################################

##################################################################################################

testthat::test_that("Test semantic query", {
  query <- do_search(rangestart=rangestart,
                     rangeend=rangeend,
                     text_filter="",
                     semantic_phrase=semantic_phrase,
                     must_have_embedding=FALSE,
                     random_sample=FALSE,
                     resultfields=resultfields,
                     return_es_query_only=TRUE)
  
  query_json <- fromJSON(query)
  test_common(query_json)
  test_not_random_sample(query_json) #For semantic search, random sampling is off regardless of param value
  test_must_have_embedding(query_json) #For semantic search, must have embeddings regardless of param value
  test_not_text_filter(query_json)
  test_semantic_phrase(query_json)
})

##################################################################################################

testthat::test_that("Test semantic query + must have embeddings", {
  query <- do_search(rangestart=rangestart,
                     rangeend=rangeend,
                     text_filter="",
                     semantic_phrase=semantic_phrase,
                     must_have_embedding=TRUE,
                     random_sample=FALSE,
                     resultfields=resultfields,
                     return_es_query_only=TRUE)
  
  query_json <- fromJSON(query)
  test_common(query_json)
  test_not_random_sample(query_json) #For semantic search, random sampling is off regardless of param value
  test_must_have_embedding(query_json) #For semantic search, must have embeddings regardless of param value
  test_not_text_filter(query_json)
  test_semantic_phrase(query_json)
})

##################################################################################################

testthat::test_that("Test semantic query + random sample", {
  query <- do_search(rangestart=rangestart,
                     rangeend=rangeend,
                     text_filter="",
                     semantic_phrase=semantic_phrase,
                     must_have_embedding=FALSE,
                     random_sample=TRUE,
                     resultfields=resultfields,
                     return_es_query_only=TRUE)
  
  query_json <- fromJSON(query)
  test_common(query_json)
  test_not_random_sample(query_json) #For semantic search, random sampling is off regardless of param value
  test_must_have_embedding(query_json) #For semantic search, must have embeddings regardless of param value
  test_not_text_filter(query_json)
  test_semantic_phrase(query_json)
})

##################################################################################################

testthat::test_that("Test semantic query + text filter", {
  query <- do_search(rangestart=rangestart,
                     rangeend=rangeend,
                     text_filter=text_filter,
                     semantic_phrase=semantic_phrase,
                     must_have_embedding=FALSE,
                     random_sample=FALSE,
                     resultfields=resultfields,
                     return_es_query_only=TRUE)
  
  query_json <- fromJSON(query)
  test_common(query_json)
  test_not_random_sample(query_json) #For semantic search, random sampling is off regardless of param value
  test_must_have_embedding(query_json) #For semantic search, must have embeddings regardless of param value
  test_text_filter(query_json)
  test_semantic_phrase(query_json)
})

##################################################################################################

testthat::test_that("Test semantic query + must have embeddings + random sample", {
  query <- do_search(rangestart=rangestart,
                     rangeend=rangeend,
                     text_filter="",
                     semantic_phrase=semantic_phrase,
                     must_have_embedding=TRUE,
                     random_sample=TRUE,
                     resultfields=resultfields,
                     return_es_query_only=TRUE)
  
  query_json <- fromJSON(query)
  test_common(query_json)
  test_not_random_sample(query_json) #For semantic search, random sampling is off regardless of param value
  test_must_have_embedding(query_json) #For semantic search, must have embeddings regardless of param value
  test_not_text_filter(query_json)
  test_semantic_phrase(query_json)
})

##################################################################################################

testthat::test_that("Test semantic query + must have embeddings + text filter", {
  query <- do_search(rangestart=rangestart,
                     rangeend=rangeend,
                     text_filter=text_filter,
                     semantic_phrase=semantic_phrase,
                     must_have_embedding=TRUE,
                     random_sample=FALSE,
                     resultfields=resultfields,
                     return_es_query_only=TRUE)
  
  query_json <- fromJSON(query)
  test_common(query_json)
  test_not_random_sample(query_json) #For semantic search, random sampling is off regardless of param value
  test_must_have_embedding(query_json) #For semantic search, must have embeddings regardless of param value
  test_text_filter(query_json)
  test_semantic_phrase(query_json)
})

##################################################################################################

testthat::test_that("Test semantic query + random sample + text filter", {
  query <- do_search(rangestart=rangestart,
                     rangeend=rangeend,
                     text_filter=text_filter,
                     semantic_phrase=semantic_phrase,
                     must_have_embedding=FALSE,
                     random_sample=TRUE,
                     resultfields=resultfields,
                     return_es_query_only=TRUE)
  
  query_json <- fromJSON(query)
  test_common(query_json)
  test_not_random_sample(query_json) #For semantic search, random sampling is off regardless of param value
  test_must_have_embedding(query_json) #For semantic search, must have embeddings regardless of param value
  test_text_filter(query_json)
  test_semantic_phrase(query_json)
})

##################################################################################################

testthat::test_that("Test semantic query + must have embeddings + random sample + text filter", {
  query <- do_search(rangestart=rangestart,
                     rangeend=rangeend,
                     text_filter=text_filter,
                     semantic_phrase=semantic_phrase,
                     must_have_embedding=TRUE,
                     random_sample=TRUE,
                     resultfields=resultfields,
                     return_es_query_only=TRUE)
  
  query_json <- fromJSON(query)
  test_common(query_json)
  test_not_random_sample(query_json) #For semantic search, random sampling is off regardless of param value
  test_must_have_embedding(query_json) #For semantic search, must have embeddings regardless of param value
  test_text_filter(query_json)
  test_semantic_phrase(query_json)
})

##################################################################################################

############################################################
## Test block 3: robustness to passing NULL instead of "" ##
############################################################

##################################################################################################

testthat::test_that("Test base query withs nulls vs. blanks", {
  query_nulls <- do_search(rangestart=rangestart,
                     rangeend=rangeend,
                     text_filter=NULL,
                     semantic_phrase=NULL,
                     must_have_embedding=FALSE,
                     random_sample=FALSE,
                     resultfields=NULL,
                     return_es_query_only=TRUE)
  
  query_blanks <- do_search(rangestart=rangestart,
                     rangeend=rangeend,
                     text_filter="",
                     semantic_phrase="",
                     must_have_embedding=FALSE,
                     random_sample=FALSE,
                     resultfields="",
                     return_es_query_only=TRUE)
  
  testthat::expect_equal(query_nulls, query_blanks)
})

##################################################################################################