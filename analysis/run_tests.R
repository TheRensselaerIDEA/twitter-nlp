if (!require("testthat")) {
  install.packages("testthat")
  library(testthat)
}

source("Elasticsearch.R")

test_results <- test_dir("tests", reporter="summary")

