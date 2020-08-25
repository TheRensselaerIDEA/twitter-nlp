if (!require("httr")) {
  install.packages("httr")
  library(httr)
}

source("text_helpers.R")

summarize <- function(text,
                      max_len=60, 
                      num_beams=4,
                      temperature=1.0,
                      model=NULL,
                      summarizer_url="http://localhost:8080/batchsummarize") {
  
  if (is.character(text) && length(text) == 1) {
    text = list(text)
  }
  
  body <- list(max_len = max_len, 
            num_beams = num_beams,
            temperature = temperature,
            text = text)
  if (!is.null(model)) {
    body$model <- model
  }
  
  res <- POST(url=summarizer_url, encode="json", body=body)
  
  res.text <- unlist(content(res))
  return(res.text)
}

summarize_tweet_clusters <- function(tweet.vectors.df,
                                    center_nn=20,
                                    max_len=60,
                                    num_beams=4,
                                    temperature=1.0,
                                    model=NULL,
                                    summarizer_url="http://localhost:8080/batchsummarize") {
  
  summaries.df <- tweet.vectors.df[tweet.vectors.df$vector_type != "tweet", 
                                   c("vector_type", "cluster", "subcluster")]
  
  #compute the subcluster text for summarization
  subcluster_summaries.df <- summaries.df[summaries.df$vector_type == "subcluster_center",]
  subcluster_summaries.df$text_for_summary <- mapply(function(cluster, subcluster) {
    nearest_center <- clusters[[cluster]]$subclusters[[subcluster]]$nearest_center
    return(concat_text_for_summary(nearest_center, center_nn))
  }, subcluster_summaries.df$cluster, subcluster_summaries.df$subcluster)
  
  #do the summarization for all subclusters in a single batch
  subcluster_summaries.df$summary <- summarize(text=subcluster_summaries.df$text_for_summary,
                                               max_len=max_len,
                                               num_beams=num_beams,
                                               temperature=temperature,
                                               model=model,
                                               summarizer_url=summarizer_url)
  summaries.df[rownames(subcluster_summaries.df), "summary"] <- subcluster_summaries.df$summary
  
  #compute the cluster text for summarization
  cluster_summaries.df <- summaries.df[summaries.df$vector_type == "cluster_center",]
  cluster_summaries.df$text_for_summary <- sapply(cluster_summaries.df$cluster, function(cluster) {
    sub_summaries_text <- data.frame(
      full_text=subcluster_summaries.df[subcluster_summaries.df$cluster==cluster, "summary"]
    )
    return(concat_text_for_summary(sub_summaries_text, nrow(sub_summaries_text)))
  })
  
  #do the summarization for all clusters in a single batch
  cluster_summaries.df$summary <- summarize(text=cluster_summaries.df$text_for_summary,
                                            max_len=max_len,
                                            num_beams=num_beams,
                                            temperature=temperature,
                                            model=model,
                                            summarizer_url=summarizer_url)
  summaries.df[rownames(cluster_summaries.df), "summary"] <- cluster_summaries.df$summary
  
  return (summaries.df)
}

