if (!require("gridExtra")) {
  install.packages("gridExtra")
  library(gridExtra)
}

if (!require("moments")) {
  install.packages("moments")
  library(moments)
}

if (!require("lubridate")) {
  install.packages("lubridate")
  library(lubridate)
}

if(!require('dplyr')) {
  install.packages("dplyr")
  library(dplyr)
}

if (!require("ggplot2")) {
  install.packages("ggplot2")
  library(ggplot2)
}

if (!require("vader")) {
  install.packages("vader")
  library(vader)
}

if (!require("egg")) {
  install.packages("egg")
  library(egg)
}

discrete_sentiment_barplot <- function(tweet.vectors.df, graph_shape, sentiment_threshold) {
  # throw out cluster and subcluster centers
  tweets.df <- tweet.vectors.df[tweet.vectors.df$vector_type == "tweet",]
  tweets.df$created_at <- as.POSIXct(strptime(tweets.df$created_at, format="%a %b %d %H:%M:%S +0000 %Y", tz="UTC"))
  tweets.df$week <- epiweek(tweets.df$created_at)  # CDC epidemiological week
  
  # create the data frame which will be used for the bar plot
  num_two_weeks <- max(as.integer(tweets.df$week / 2))
  # num_two_weeks <- tweets.df$created_at %>% week() / 2 %>% max(as.integer())
  summary.df <- data.frame(two_week = rep(c(1:num_two_weeks), each=3), sentiment = factor(rep(c("positive", "neutral", "negative"), num_two_weeks), levels = c("negative", "neutral", "positive"), ordered=TRUE), count = 0, binned_date = ymd("2019-12-22"))
  summary.df$binned_date <- summary.df$binned_date + (14 * summary.df$two_week)
  
  # because summarize() brings about mysterious errors
  # take counts and mean of sentiment
  for (i in 1:length(tweets.df$week)) {
    # temporary hack / TODO
    j <- as.integer(tweets.df[i,]$week / 2)
    
    if (tweets.df[i,]$sentiment >= sentiment_threshold) {
      summary.df[3*j-2,]$count = summary.df[3*j-2,]$count + 1
    } else if (tweets.df[i,]$sentiment <= - sentiment_threshold) {
      summary.df[3*j,]$count = summary.df[3*j,]$count + 1
    } else {
      summary.df[3*j -1,]$count = summary.df[3*j -1,]$count + 1
    }
  }
  
  # colors  source: Color Brewer 2.0
  colors <- c("positive" = "#91BFDB", "neutral" = "#FFFFBF", "negative" = "#FC8D59") # colorblind friendly
  
  # bar plot showing sentiment over time
  ggplot(summary.df, aes(x = binned_date, y = count, fill=sentiment)) + 
    geom_bar(stat = "identity", color = "azure3", position = graph_shape, width=11) + 
    scale_color_manual(values = colors, aesthetics = c("colour", "fill")) +
    coord_cartesian(xlim = c(ymd("2020-03-08"), ymd("2020-08-01"))) +
    ggtitle("Tweet Counts by Sentiment", subtitle = "Tweets binned into two week periods") + 
    ylab("Tweet Count") +
    theme(axis.title.x = element_blank(), panel.background = element_rect(fill = "#33352C", colour = "#EFF0F0"))
}

continuous_sentiment_barplot <- function(tweet.vectors.df) {
  # filter out centers from the dataframe
  tweets.df <- tweet.vectors.df[tweet.vectors.df$vector_type == "tweet",]
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
    } else if (summary.df[i,]$sentiment_mean <= - sentiment_threshold) {
      summary.df[i,]$sentiment <- "negative"
    } else {
      summary.df[i,]$sentiment <- "neutral"
    }
  }
  
  # colors  source: Color Brewer 2.0
  colors <- c("positive" = "#91BFDB", "neutral" = "#FFFFBF", "negative" = "#FC8D59") # colorblind friendly
  
  # bar plot showing sentiment over time
  ggplot(summary.df, aes(x = binned_date, y = sentiment_mean, fill=sentiment)) + 
    geom_bar(stat = "identity", color = "azure3", position = graph_shape) + 
    scale_color_manual(values = colors, aesthetics = c("colour", "fill")) +
    coord_cartesian(xlim = c(ymd("2020-03-08"), ymd("2020-08-01"))) +
    ggtitle("Sentiment over Time", subtitle = "Tweets binned in one week intervals") + 
    ylab("Tweet Count") +
    theme(axis.title.x = element_blank(), panel.background = element_rect(fill = "#33352C", colour = "#EFF0F0"))
  
}

cluster_sentiments_plots <- function(tweet.vectors.df) {
  # filter out centers from the dataframe
  tweets.df <- tweet.vectors.df[tweet.vectors.df$vector_type == "tweet",]
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
  
  # bar plot showing sentiment over time
  ggplot(summary.df, aes(x = binned_date, y = count, fill = sentiment_mean)) + 
    geom_bar(stat = "identity", color = "azure3") + 
    scale_fill_gradient2(name = "Sentiment Average", limits = c(-0.5,0.5), low = "#FC8D59", mid = "white", high = "#91BFDB", midpoint = 0) +
    ggtitle("Sentiment by Week for each Cluster", subtitle = "Tweets binned in one-week intervals") + 
    ylab("Tweet Count") +
    coord_cartesian(xlim = c(ymd("2020-03-08"), ymd("2020-08-01"))) +
    theme(axis.title.x = element_blank()) +
    facet_wrap(~ cluster, ncol = 3)
}