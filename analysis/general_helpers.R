################################################################
# General helper functions
################################################################

order_clusters_by_avg_sentiment <- function(tweet.vectors.df) {
  # test to see if sentiment is available
  if (nrow(tweet.vectors.df[!is.na(tweet.vectors.df$sentiment),]) == 0) {
    return (tweet.vectors.df)
  }
    
  tweet.sentiment.df <- tweet.vectors.df[tweet.vectors.df$vector_type == "tweet", 
                                         c("cluster", "subcluster", "sentiment")]
  tweet.sentiment.df[is.na(tweet.sentiment.df$sentiment), "sentiment"] <- 0
  
  #Reorder clusters
  centers.df <- tweet.vectors.df[tweet.vectors.df$vector_type == "cluster_center",]
  k <- max(centers.df$cluster)
  centers.df$sentiment <- sapply(centers.df$cluster, function(c) {
    mean(tweet.sentiment.df[tweet.sentiment.df$cluster==c, "sentiment"])
  })
  centers.df <- centers.df[order(centers.df$sentiment),]
  centers.df$new_cluster <- 1:k
  tweet.vectors.df$cluster <- sapply(tweet.vectors.df$cluster, function(c) {
    centers.df[centers.df$cluster==c, "new_cluster"]
  })
  tweet.vectors.df[rownames(centers.df), "sentiment"] <- centers.df$sentiment
  tweet.vectors.df[rownames(centers.df), "full_text"] <- paste("Cluster (", centers.df$new_cluster, 
                                                               ") Center", sep="")
  
  #Reorder subclusters
  centers.df <- tweet.vectors.df[tweet.vectors.df$vector_type == "subcluster_center",]
  for (i in 1:k) {
    cluster.centers.df <- centers.df[centers.df$cluster==i,]
    cluster.k <- max(cluster.centers.df$subcluster)
    cluster.sentiment.df <- tweet.sentiment.df[tweet.sentiment.df$cluster==i,]
    cluster.centers.df$sentiment <- sapply(cluster.centers.df$subcluster, function(c) {
      mean(cluster.sentiment.df[cluster.sentiment.df$subcluster==c, "sentiment"])
    })
    cluster.centers.df <- cluster.centers.df[order(cluster.centers.df$sentiment),]
    cluster.centers.df$new_subcluster <- 1:cluster.k
    tweet.vectors.df[tweet.vectors.df$cluster==i, "subcluster"] <- sapply(
      tweet.vectors.df[tweet.vectors.df$cluster==i, "subcluster"], function(c) {
        cluster.centers.df[cluster.centers.df$subcluster==c, "new_subcluster"]
      }
    )
    tweet.vectors.df[rownames(cluster.centers.df), "sentiment"] <- cluster.centers.df$sentiment
    tweet.vectors.df[rownames(cluster.centers.df), "full_text"] <- paste("Subcluster (", 
                                                                         cluster.centers.df$new_subcluster, 
                                                                         ") Center", sep="")
  }
  
  return (tweet.vectors.df)
}