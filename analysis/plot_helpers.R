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

if (!require('lubridate')) {
  install.packages("lubridate")
  library(lubridate)
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
sentiment_to_html_emoji <- function(sentiment_score, sentiment_threshold) {
  return (sapply(sentiment_score, function(s) {
    if (is.na(s)) { return ("") }
    if (s >= sentiment_threshold) { return ("&#128515;") }
    if (s <= -sentiment_threshold) { return ("&#128545;") }
    return ("&#128528;")
  }))
}

################################################################
# Plots tweet clusters or subclusters as points in 2d or 3d space, 
# colored by their cluster or subcluster membership.
# Cluster / subcluster centers are highlighted in black.
################################################################
plot_tweets <- function(tsne.plot, title, sentiment_threshold, type, mode, webGL) {
  isWebGL <- isTRUE(webGL) && mode=="2d"
  
  plot_type <- if(type=="clusters") {"Cluster"} else {"Subcluster"}
  centers_trace_vector_type <- if (type == "clusters") {"cluster_center"} else {"subcluster_center"}
  
  fig <- plot_ly(tsne.plot[tsne.plot$vector_type == "tweet",], 
                 x=~if(type=="subclusters_regrouped") {cluster.X} else {X}, 
                 y=~if(type=="subclusters_regrouped") {cluster.Y} else {Y}, 
                 z=~if(type=="subclusters_regrouped") {cluster.Z} else {Z},
                 hoverinfo = "text",
                 hovertext=~paste(paste0(plot_type, ":"), 
                             if(type=="clusters") {cluster} else {subcluster},
                             "<br>Sentiment:", round(sentiment, 4), 
                              sentiment_to_html_emoji(sentiment, sentiment_threshold),
                             "<br>Tweet ID:", paste0("[", id_str, "]")),
                 color=~if(type=="clusters") {cluster.label} else {subcluster.label}, 
                 colors=colorRamp(brewer.pal(8, "Set2")), 
                 type=if(mode=="3d") {"scatter3d"} else {"scatter"}, 
                 mode="markers",
                 marker=list(size=if(mode=="3d") {3} else {5}),
                 legendgroup=~if(type=="clusters") {cluster.label} else {subcluster.label})
  
  fig <- fig %>% add_trace(data=tsne.plot[tsne.plot$vector_type == centers_trace_vector_type,],
                           text=~paste0(ifelse(isWebGL, "", "<b>"), 
                                        if(type=="clusters") {cluster} else {paste(cluster, subcluster, sep=".")}, 
                                        ifelse(isWebGL, "", "</b>")),
                           textposition="top right",
                           textfont=list(size=11, color="rgb(0, 0, 0)"),
                           hovertext=~paste(paste0(plot_type, ":"),
                                            if(type=="clusters") {cluster} else {subcluster}, "(Center)",
                                            paste("<br>Avg.", plot_type ,"Sentiment:"), round(sentiment, 4), 
                                            sentiment_to_html_emoji(sentiment, sentiment_threshold),
                                            "<br>Generated Summary:", full_text),
                           mode="markers+text",
                           marker=list(size=if(mode=="3d") {6} else {10}, color="rgb(0, 0, 0)"),
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
  
  if (isWebGL) {
    fig <- fig %>% toWebGL()
  }
  
  return(fig)
}

################################################################
# Generate bar plot showing discrete sentiment over time
# from a collection of tweets
################################################################
discrete_sentiment_lines <- function(tweet.vectors.df, sentiment_threshold, plot_range_start=NA, plot_range_end=NA) {
  # throw out cluster and subcluster centers
  tweets.df <- tweet.vectors.df[tweet.vectors.df$vector_type == "tweet",]
  # test to see if sentiment is available
  tweets.df <- tweets.df[!is.na(tweets.df$sentiment),]
  if (nrow(tweets.df) == 0) {
    return ("Cannot generate discrete sentiment plot - sentiment scores are not available in the sample.")
  }
  
  tweets.df$created_at <- as.POSIXct(strptime(tweets.df$created_at, format="%a %b %d %H:%M:%S +0000 %Y", tz="UTC"))
  tweets.df$week <- epiweek(tweets.df$created_at)  # CDC epidemiological week
  
  # create the data frame which will be used for the bar plot
  num_weeks <- max(as.integer(tweets.df$week))
  # num_two_weeks <- tweets.df$created_at %>% week() / 2 %>% max(as.integer())
  summary.df <- data.frame(weeks = rep(c(1:num_weeks), each=3), sentiment = factor(rep(c("positive", "neutral", "negative"), num_weeks), levels = c("negative", "neutral", "positive"), ordered=TRUE), count = 0, binned_date = ymd("2019-12-29"))
  summary.df$binned_date <- summary.df$binned_date + (7 * summary.df$weeks)
  
  # because summarize() brings about mysterious errors
  # take counts and mean of sentiment
  for (i in 1:length(tweets.df$week)) {
    # temporary hack / TODO
    j <- as.integer(tweets.df[i,]$week)
    
    if (tweets.df[i,]$sentiment >= sentiment_threshold) {
      summary.df[3*j-2,]$count = summary.df[3*j-2,]$count + 1
    } else if (tweets.df[i,]$sentiment <= - sentiment_threshold) {
      summary.df[3*j,]$count = summary.df[3*j,]$count + 1
    } else {
      summary.df[3*j -1,]$count = summary.df[3*j -1,]$count + 1
    }
  }
  
  # remove empty rows
  summary.df <- summary.df %>% subset(count != 0)
  
  #filter by date
  if (!is.na(plot_range_start)) {
    summary.df <- summary.df %>% subset(summary.df$binned_date >= ymd(plot_range_start))
  }
  if (!is.na(plot_range_end)) {
    summary.df <- summary.df %>% subset(summary.df$binned_date <= ymd(plot_range_end))
  }
  
  # colors  source: Color Brewer 2.0
  colors <- c("positive" = "#91BFDB", "neutral" = "#FFFFBF", "negative" = "#FC8D59") # colorblind friendly
  
  # bar plot showing sentiment over time
  ggplot(summary.df, aes(x = binned_date, y = count, group=sentiment, color=sentiment)) + 
    geom_line(width = 3) + geom_point(size=5) +
    scale_color_manual(values = colors, aesthetics = c("colour", "fill")) +
    ggtitle("Tweet Counts by Sentiment (for entire sample)", subtitle = "Tweets binned into one week periods") + 
    ylab("Tweet Count") +
    theme(axis.title.x = element_blank(), panel.background = element_rect(fill = "#CAD0C8", colour = "black"))
}

################################################################
# Generate bar plot showing continuous sentiment over time
# from a collection of tweets. The continuous sentiment score
# is converted to discrete sentiment classes using a threshold.
################################################################
continuous_sentiment_barplot <- function(tweet.vectors.df, sentiment_threshold, plot_range_start=NA, plot_range_end=NA) {
  # filter out centers from the dataframe
  tweets.df <- tweet.vectors.df[tweet.vectors.df$vector_type == "tweet",]
  # test to see if sentiment is available
  tweets.df <- tweets.df[!is.na(tweets.df$sentiment),]
  if (nrow(tweets.df) == 0) {
    return ("Cannot generate continuous sentiment plot - sentiment scores are not available in the sample.")
  }
  
  tweets.df$created_at <- as.POSIXct(strptime(tweets.df$created_at, format="%a %b %d %H:%M:%S +0000 %Y", tz="UTC"))
  tweets.df$week <- epiweek(tweets.df$created_at)  # find CDC epidemiological week
  
  num_weeks <- max(tweets.df$week)
  
  # create the data frame which will be used for the bar plot
  summary.df <- data.frame(week = c(1:num_weeks), count = 0, sentiment = "", sentiment_mean = 0, binned_date = ymd("2019-12-22"))
  summary.df$binned_date <- summary.df$binned_date + (7 * summary.df$week)
  
  for (i in 1:length(tweets.df$week)) {
    j <- tweets.df[i,]$week
    summary.df[j,]$count = summary.df[j,]$count + 1
    summary.df[j,]$sentiment_mean = summary.df[j,]$sentiment_mean + tweets.df[i,]$sentiment
  }
  summary.df$sentiment_mean = summary.df$sentiment_mean / summary.df$count
  
  summary.df$sentiment <- summary.df$sentiment %>% factor(levels = c("negative", "neutral", "positive"), ordered = TRUE)
  
  #set NaNs to 0
  summary.df$sentiment_mean[is.na(summary.df$sentiment_mean)] <- 0
  
  # discretize sentiment
  for (i in 1:num_weeks) {
    if (summary.df[i,]$sentiment_mean >= sentiment_threshold) {
      summary.df[i,]$sentiment <- "positive"
    } else if (summary.df[i,]$sentiment_mean <= -sentiment_threshold) {
      summary.df[i,]$sentiment <- "negative"
    } else {
      summary.df[i,]$sentiment <- "neutral"
    }
  }
  
  # remove empty rows
  summary.df <- summary.df %>% subset(count != 0)
  
  #filter by date
  if (!is.na(plot_range_start)) {
    summary.df <- summary.df %>% subset(summary.df$binned_date >= ymd(plot_range_start))
  }
  if (!is.na(plot_range_end)) {
    summary.df <- summary.df %>% subset(summary.df$binned_date <= ymd(plot_range_end))
  }
  
  # colors  source: Color Brewer 2.0
  colors <- c("positive" = "#91BFDB", "neutral" = "#FFFFBF", "negative" = "#FC8D59") # colorblind friendly
  
  # bar plot showing sentiment over time
  ggplot(summary.df, aes(x = binned_date, y = sentiment_mean, fill=sentiment)) + 
    geom_bar(stat = "identity", color = "azure3") +
    #geom_line(y = sentiment_threshold, color="black") + geom_line(y = -sentiment_threshold, color="black") +
    scale_color_manual(values = colors, aesthetics = c("colour", "fill")) +
    ggtitle("Sentiment over Time (for entire sample)", subtitle = "Tweets binned in one week intervals") + 
    ylab("Mean Sentiment") +
    theme(axis.title.x = element_blank(), panel.background = element_rect(fill = "#CAD0C8", colour = "#EFF0F0"))
  
}

################################################################
# Generate bar plot showing cluster sentiment over time from a
# collection of tweets grouped into k clusters
################################################################
cluster_sentiments_plots <- function(tweet.vectors.df, k, plot_range_start=NA, plot_range_end=NA) {
  # filter out centers from the dataframe
  tweets.df <- tweet.vectors.df[tweet.vectors.df$vector_type == "tweet",]
  # test to see if sentiment is available
  tweets.df <- tweets.df[!is.na(tweets.df$sentiment),]
  if (nrow(tweets.df) == 0) {
    return ("Cannot generate cluster sentiment plot - sentiment scores are not available in the sample.")
  }
  
  tweets.df$created_at <- as.POSIXct(strptime(tweets.df$created_at, format="%a %b %d %H:%M:%S +0000 %Y", tz="UTC"))
  tweets.df$week <- epiweek(tweets.df$created_at)  # find CDC epidemiological week
  
  num_weeks <- max(tweets.df$week)
  
  # define titles of clusters
  titles <- rep("Cluster", k)
  titles <- titles %>% paste(c(1:k))
  titles <- factor(titles, levels = titles, ordered = TRUE)
  
  # create the data frame which will be used for the bar plot
  summary.df <- data.frame(week = rep(c(1:num_weeks), k), cluster = rep(titles, each=num_weeks), count = 0, sentiment_mean = 0, binned_date = ymd("2019-12-22"))
  summary.df$binned_date <- summary.df$binned_date + (7 * summary.df$week)
  
  for (i in 1:length(tweets.df$week)) {
    wk <- tweets.df[i,]$week
    cl <- tweets.df[i,]$cluster
    # temporary hack
    j <- (cl - 1) * num_weeks + wk
    #summary.df[summary.df$week == wk && summary.df$cluster == cl,]$count = summary.df[summary.df$week == wk && summary.df$cluster == cl,]$count + 1
    ##summary.df$count <- (summary.df %>% filter(week == wk & cluster == cl))$count + 1
    summary.df[j,]$count = summary.df[j,]$count + 1
    #summary.df[summary.df$week == wk && summary.df$cluster == cl,]$sentiment_mean = summary.df[summary.df$week == wk && summary.df$cluster == cl,]$sentiment_mean + tweets.df[i,]$sentiment
    summary.df[j,]$sentiment_mean = summary.df[j,]$sentiment_mean + tweets.df[i,]$sentiment
  }
  summary.df$sentiment_mean = summary.df$sentiment_mean / summary.df$count
  
  #set NaNs to 0
  summary.df$sentiment_mean[is.na(summary.df$sentiment_mean)] <- 0
  
  # remove empty rows
  summary.df <- summary.df %>% subset(summary.df$count != 0)
  
  #filter by date
  if (!is.na(plot_range_start)) {
    summary.df <- summary.df %>% subset(summary.df$binned_date >= ymd(plot_range_start))
  }
  if (!is.na(plot_range_end)) {
    summary.df <- summary.df %>% subset(summary.df$binned_date <= ymd(plot_range_end))
  }
  
  # bar plot showing sentiment over time
  ggplot(summary.df, aes(x = binned_date, y = count, fill = sentiment_mean)) + 
    geom_bar(stat = "identity", color = "azure3") + 
    scale_fill_gradient2(name = "Sentiment Average", limits = c(-0.5,0.5), low = "#FC8D59", mid = "white", high = "#91BFDB", midpoint = 0) +
    ggtitle("Sentiment by Week (for each cluster)", subtitle = "Tweets binned in one-week intervals") + 
    ylab("Tweet Count") +
    theme(axis.title.x = element_blank()) +
    facet_wrap(~ cluster, ncol = 3)
}

################################################################
# Generate line graph showing each sentiment class for each
# cluster, over time
################################################################
cluster_discrete_sentiments <- function(tweet.vectors.df, sentiment_threshold, k, plot_range_start=NA, plot_range_end=NA) {
  # throw out cluster and subcluster centers
  tweets.df <- tweet.vectors.df[tweet.vectors.df$vector_type == "tweet",]
  # test to see if sentiment is available
  tweets.df <- tweets.df[!is.na(tweets.df$sentiment),]
  if (nrow(tweets.df) == 0) {
    return ("Cannot generate discrete sentiment plot - sentiment scores are not available in the sample.")
  }
  
  tweets.df$created_at <- as.POSIXct(strptime(tweets.df$created_at, format="%a %b %d %H:%M:%S +0000 %Y", tz="UTC"))
  tweets.df$week <- epiweek(tweets.df$created_at)  # CDC epidemiological week
  
  # create the data frame which will be used for the bar plot
  num_weeks <- max(as.integer(tweets.df$week))
  
  # define titles of clusters
  titles <- rep("Cluster", k)
  titles <- titles %>% paste(c(1:k))
  titles <- factor(titles, levels = titles, ordered = TRUE)
  
  # create the data frame which will be used for the bar plot
  summary.df <- data.frame(week = rep(c(1:num_weeks), each=3, k), sentiment = factor(rep(c("positive", "neutral", "negative"), num_weeks * k), levels = c("negative", "neutral", "positive"), ordered=TRUE), cluster = rep(titles, each=3 * num_weeks), count = 0, binned_date = ymd("2019-12-29"))
  summary.df$binned_date <- summary.df$binned_date + (7 * summary.df$week)
  
  for (i in 1:length(tweets.df$week)) {
    wk <- tweets.df[i,]$week
    cl <- tweets.df[i,]$cluster
    # temporary hack
    j <- 3 * (cl - 1) * num_weeks + 3 * wk
    
    if (tweets.df[i,]$sentiment >= sentiment_threshold) {
      summary.df[j-2,]$count = summary.df[j-2,]$count + 1
    } else if (tweets.df[i,]$sentiment <= - sentiment_threshold) {
      summary.df[j,]$count = summary.df[j,]$count + 1
    } else {
      summary.df[j-1,]$count = summary.df[j-1,]$count + 1
    }
  }
  
  # remove empty rows
  summary.df <- summary.df %>% subset(summary.df$count != 0)
  
  #filter by date
  if (!is.na(plot_range_start)) {
    summary.df <- summary.df %>% subset(summary.df$binned_date >= ymd(plot_range_start))
  }
  if (!is.na(plot_range_end)) {
    summary.df <- summary.df %>% subset(summary.df$binned_date <= ymd(plot_range_end))
  }
  
  # colors  source: Color Brewer 2.0
  colors <- c("positive" = "#91BFDB", "neutral" = "#FFFFBF", "negative" = "#FC8D59") # colorblind friendly
  
  # bar plot showing sentiment over time
  ggplot(summary.df, aes(x = binned_date, y = count, group=sentiment, color=sentiment)) + 
    geom_line() + geom_point() +
    scale_color_manual(values = colors, aesthetics = c("colour", "fill")) +
    ggtitle("Tweet Counts by Sentiment (for each cluster)", subtitle = "Tweets binned into one week periods") + 
    ylab("Tweet Count") +
    theme(axis.title.x = element_blank(), panel.background = element_rect(fill = "#CAD0C8", colour = "black")) +
    facet_wrap(~ cluster, ncol = 3)
}

load_tweet_viewer <- function() {
  viewer_html <- '
    <script type="text/javascript">
      var oEmbed_xhr = null;
      var oEmbed_timer = null;
      $(window).load(function() {
        var plots = $(".js-plotly-plot");
        for (var i = 0; i < plots.length; i++){
          $(".js-plotly-plot")[i].on("plotly_hover", function(data) {
            oEmbed_timer = setTimeout(function() {
              oEmbed_timer = null;
              var point = data.points[0];
              var hovertext = point.hovertext ? point.hovertext : point.data.hovertext;
              tweet_id_parts = hovertext.split("[");
              if (tweet_id_parts.length < 2) {
                return;
              }
              tweet_id_parts = tweet_id_parts[1].split("]");
              if (tweet_id_parts.length < 1) {
                return;
              }
              tweet_id = tweet_id_parts[0];
              embed_url = "https://publish.twitter.com/oembed?url=https://twitter.com/user/status/" + tweet_id;
              oEmbed_xhr = $.ajax({
                type: "GET",
                url: embed_url,
                dataType: "jsonp",
                success: function(result) {
                  $("#tweetEmbed").html(result.html);
                  $("#tweetEmbed").show();
                },
                error: function(xhr, status, msg) {
                  errorhtml = "Could not load tweet:<br />" + status + "<br />" + msg;
                  $("#tweetEmbed").html(errorhtml);
                  $("#tweetEmbed").show();
                },
                complete: function() {
                  oEmbed_xhr = null;
                }
              });
            }, 300);
          });
          $(".js-plotly-plot")[i].on("plotly_unhover", function(data) {
            if (oEmbed_timer) {
              clearTimeout(oEmbed_timer);
              oEmbed_timer = null;
            }
            if (oEmbed_xhr && oEmbed_xhr.readyState != 4) {
              oEmbed_xhr.abort();
              oEmbed_xhr = null;
            }
            var tweetEmbed = $("#tweetEmbed");
            if(tweetEmbed.is(":visible")) {
              tweetEmbed.html("");
              tweetEmbed.hide();
            }
          });
        }
      });
   </script>
   <div id="tweetEmbed"></div>
  <style type="text/css">
    #tweetEmbed {
      position: fixed;
      top: 0px;
      left: 0px;
      width: 20%;
      display: none;
    }
  </style>'
  
  return(viewer_html)
}
