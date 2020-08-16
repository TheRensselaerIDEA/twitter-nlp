################################################################
# Helper functions for generating plots for twitter analysis
################################################################

if (!require("ggplot2")) {
  install.packages("ggplot2")
  library(ggplot2)
}

if(!require('plotly')) {
  install.packages("plotly")
  library(plotly)
}

if(!require('RColorBrewer')) {
  install.packages("RColorBrewer")
  library(RColorBrewer)
}

if(!require('cluster')) {
  install.packages("cluster")
  library(cluster)
}

################################################################
# Computes and returns elbow and/or silhouette plots 
# for master kmeans clusters
################################################################
plot_kmeans_metrics <- function(data, k_test_range, seed, max_iter, nstart, plot_elbow, plot_silhouette){
  plots <- list()
  if (isTRUE(plot_elbow) || isTRUE(plot_silhouette)) {
    metrics <- data.frame(k=k_test_range, withinss=c(0), sil_width=c(0))
    for (i in k_test_range){
      if (!is.na(seed)) {
        set.seed(seed)
      }
      km <- kmeans(data, centers=i, iter.max=max_iter, nstart=nstart)
      metrics_idx <- i-min(k_test_range)+1
      if (isTRUE(plot_elbow)) {
        metrics[metrics_idx,2] <- sum(km$withinss)
      }
      if (isTRUE(plot_silhouette)) {
        SIL<-silhouette(km$cluster, dist(data))
        metrics[metrics_idx,3]<-mean(SIL[,3])
      }
    }
    plot_index <- 1
    if (isTRUE(plot_elbow)) {
      
      plots[[plot_index]] <- ggplot(data=metrics,aes(x=k,y=withinss)) + 
        geom_line() + 
        ggtitle("Quality (within sums of squares) of k-means by choice of k")
      plot_index <- plot_index + 1
    }
    if (isTRUE(plot_silhouette)) {
      plots[[plot_index]] <- ggplot(data=metrics,aes(x=k,y=sil_width)) + 
        geom_line() + 
        ggtitle("Quality (silhouette width) of k-means by choice of k")
      plot_index <- plot_index + 1
    }
  }
  return(plots)
}

################################################################
# Computes and returns elbow plot with axis for each cluster's
# subclusters
################################################################
wssplot2 <- function(data, k_test_range, seed, max_iter, nstart){
  clusters <- max(data[,1])
  wss <- data.frame(cluster=as.factor(sort(rep(1:clusters, max(k_test_range)-min(k_test_range)+1))), 
                    k=rep(k_test_range, clusters), withinss=c(0))
  for (i in 1:clusters) {
    for (j in k_test_range){
      if (!is.na(seed)){
        set.seed(seed)
      }
      wss_idx <- j-min(k_test_range)+1
      wss[wss$cluster==i,][wss_idx,"withinss"] <- sum(kmeans(data[data[,1]==i,2:ncol(data)], centers=j, 
                                                       iter.max=max_iter, 
                                                       nstart=nstart)$withinss)
    }
  }
  wss$withinss.scaled <- unlist(lapply(1:clusters, function(n) scale(wss$withinss[wss$cluster==n])))
  ggplot(data=wss,aes(x=k,y=withinss.scaled)) + 
    geom_line(aes(color=cluster, linetype=cluster)) + 
    ggtitle("Quality (scaled within sums of squares) of k-means by choice of k")
}


################################################################
# Converts sentiment score to emoji based on a given threshold
################################################################
sentiment_to_html_emoji <- function(sentiment_score, threshold) {
  return (sapply(sentiment_score, function(s) {
    if (is.na(s)) { return ("") }
    if (s >= threshold) { return ("&#128515;") }
    if (s <= -threshold) { return ("&#128545;") }
    return ("&#128528;")
  }))
}

################################################################
# Plots tweet clusters or subclusters as points in 2d or 3d space, 
# colored by their cluster or subcluster membership.
# Cluster / subcluster centers are highlighted in black.
################################################################
plot_tweets <- function(tsne.plot, title, sentiment_threshold, type, mode, webGL) {
  fig <- plot_ly(tsne.plot[tsne.plot$vector_type == "tweet",], 
                 x=~if(type=="subclusters_regrouped") {cluster.X} else {X}, 
                 y=~if(type=="subclusters_regrouped") {cluster.Y} else {Y}, 
                 z=~if(type=="subclusters_regrouped") {cluster.Z} else {Z},
                 hoverinfo = "text",
                 text=~paste(if(type=="clusters") {"Cluster:"} else {"Subcluster:"}, 
                             if(type=="clusters") {cluster} else {subcluster},
                             "<br>Sentiment:", sentiment, sentiment_to_html_emoji(sentiment, sentiment_threshold),
                             "<br>Text:", full_text), 
                 color=~if(type=="clusters") {cluster.label} else {subcluster.label}, 
                 colors=colorRamp(brewer.pal(8, "Set2")), 
                 type=if(mode=="3d") {"scatter3d"} else {"scatter"}, 
                 mode="markers",
                 marker=list(size=if(mode=="3d") {3} else {5}),
                 legendgroup=~if(type=="clusters") {cluster.label} else {subcluster.label})
  
  centers_trace_vector_type <- if (type == "clusters") {"cluster_center"} else {"subcluster_center"}
  fig <- fig %>% add_trace(data=tsne.plot[tsne.plot$vector_type == centers_trace_vector_type,],
                           marker=list(size=if(mode=="3d") {6} else {10}, color='rgb(0, 0, 0)'),
                           legendgroup=~if(type=="clusters") {cluster.label} else {subcluster.label},
                           showlegend=FALSE)
  
  if (mode == "3d") {
    fig <- fig %>% layout(title=title, scene=list(xaxis=list(zeroline=FALSE, title="X"), 
                                                  yaxis=list(zeroline=FALSE, title="Y"), 
                                                  zaxis=list(zeroline=FALSE, title="Z")))
  } else {
    fig$x$attrs[[1]]$z <- NULL #remove unused z axis
    fig$x$attrs[[2]]$z <- NULL
    fig <- fig %>% layout(title=title, xaxis=list(zeroline=FALSE, title="X"), 
                          yaxis=list(zeroline=FALSE, title="Y"),
                          legend=list(traceorder="normal"))
  }
  
  if (isTRUE(webGL) && mode=="2d") {
    fig <- fig %>% toWebGL()
  }
  
  return(fig)
}