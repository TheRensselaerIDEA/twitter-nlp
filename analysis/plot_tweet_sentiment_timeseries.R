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


# check the city is in the location 
find_state <- function(x){
  state_lst <- list()
}

# Compute divisiveness score from vector of sentiments
divisiveness_score <- function(x) {
  ########################################################################################
  # INPUT:
  #   x : vector of VADER compound sentiment scores
  # OUTPUT:
  #   vector of divisiveness scores
  # 
  # Divisiveness score ranges between -∞ and ∞
  # score = ∞  ==> absolute division of sentiments (ex: Bernoulli dist.)
  # score = 0  ==> sentiments are perfectly spread out (ex: uniform dist.)
  # score = -∞ ==> absolute consensus of sentiments (ex: Laplace dist. with small scale)
  # For more information on the Sarle's bimodality coefficient, check out the article:
  # ---
  # Pfister R, Schwarz KA, Janczyk M, Dale R, Freeman JB. Good things peak in pairs: a 
  # note on the bimodality coefficient. Front Psychol. 2013;4:700. Published 2013 Oct 2. 
  # doi:10.3389/fpsyg.2013.00700
  # ---
  ########################################################################################
  
  BC <- (moments::skewness(x)^2 + 1) / moments::kurtosis(x) # compute Sarle's BC
  return(-log(1 / BC - 1) + log(4/5))
}

# Return plot of tweet counts, average sentiments and divisiveness over time. 
# Can plot moving averages of counts, sentiment and divisiveness, as well as group by day or week
plot_tweet_sentiment_timeseries <- function(tweet.vectors.df, group.by = "day", compute.sentiment = FALSE, plot.ma = FALSE, ma.n = 5, ma.type = "simple") {
  #########################################################################################################################
  # INPUT:
  #   tweet.vectors.df  : Dataframe of tweets, MUST INCLUDE THE FIELS: `created_at`, `vector_type`.
  #                       FIELD `sentiment` IS OPTIONAL BUT GREATLY SPEEDS UP COMPUTATION.
  #   group.by          : Time frame by which to group tweets, either "day" or "week.
  #   plot.ma           : Whether to plot the moving average of tweet counts, sentiments and divisiveness.
  #   ma.n              : If plotting the moving average, the number of timesteps to be used in the computation.
  #   ma.type           : If plotting the moving average, the type of moving averge to use. Options are: "simple" for SMA; 
  #                       "exponential" for EMA; "weighted" for WMA
  # OUTPUT:
  #   ggplot figure of tweet counts, average sentiment and divisiveness over time.
  #########################################################################################################################
  tweets.df <- tweet.vectors.df[tweet.vectors.df$vector_type == "tweet",]
  if (compute.sentiment == TRUE) {
    tweet.vectors.df$sentiment <- c(0)
    sentiment.vector <- rep(NA, length(tweet.vectors.df$sentiment))
    for (i in 1:length(tweet.vectors.df$sentiment)) {
      tryCatch({
        sentiment.vector[i] <- get_vader(tweet.vectors.df$full_text[i])["compound"]
      }, error = function(e) {
        sentiment.vector[i] <- NA
      })
    }
    tweet.vectors.df$sentiment <- sentiment.vector
    tweet.vectors.df <- tweet.vectors.df[!is.na(sentiment.vector),]
  }
  tweets.df$created_at <- as.POSIXct(strptime(tweets.df$created_at, format="%a %b %d %H:%M:%S +0000 %Y", tz="UTC"))
  tweets.df$week <- epiweek(tweets.df$created_at)  # find CDC epidemiological week
  tweets.df$date <- date(tweets.df$created_at)
  tweet.tibble <- tibble(sentiment = tweets.df$sentiment, week = tweets.df$week, date = tweets.df$date, datetime = tweets.df$created_at)
  if (group.by == "week") {
    # Compute statistics
    summary.tibble <- tweet.tibble %>% group_by(week) %>% summarize(mean_sentiment = mean(sentiment), sd_sentiment = sd(sentiment),);
    summary.tibble <- tweet.tibble %>% group_by(week) %>% summarize(mean_sentiment = mean(sentiment), sd_sentiment = sd(sentiment), count = length(datetime), divisiveness = divisiveness_score(sentiment))
    summary.tibble$divisiveness[is.na(summary.tibble$divisiveness)] <- 0
    if (plot.ma == TRUE) {
      # Compute moving averages
      if (ma.type == "weighted") {
        summary.tibble <- summary.tibble %>% mutate(sentiment_MA = WMA(mean_sentiment, ma.n), count_MA = WMA(count, ma.n), divisiveness_MA = WMA(divisiveness, ma.n))
      } else if (ma.type == "exponential") {
        summary.tibble <- summary.tibble %>% mutate(sentiment_MA = EMA(mean_sentiment, ma.n), count_MA = EMA(count, ma.n), divisiveness_MA = EMA(divisiveness, ma.n))
      } else {
        summary.tibble <- summary.tibble %>% mutate(sentiment_MA = SMA(mean_sentiment, ma.n), count_MA = SMA(count, ma.n), divisiveness_MA = SMA(divisiveness, ma.n))
      }
    }
    summary.tibble <- summary.tibble %>% ungroup()
    # Plot tweet counts and average sentiments
    fig1 <- ggplot(summary.tibble, aes(x = week, y = count, fill = mean_sentiment)) + 
      geom_bar(stat = "identity", color = "azure3") + 
      scale_fill_gradient2(name = "Sentiment Average", limits = c(-1,1), low = "red", mid = "white", high = "green", midpoint = 0) +
      ggtitle("Tweets by Week") + 
      ylab("Tweet Count") +
      theme(axis.title.x = element_blank())
    # Plot divisiness
    fig2 <- ggplot(summary.tibble, aes(x = week, y = divisiveness)) + 
      geom_bar(fill = "purple", stat = "identity") + 
      geom_hline(yintercept = 0, color = "red", linetype = "dashed") +
      ylab("Divisiveness") +
      xlab("Date") + 
      theme_grey(base_size = 9) 
    if (plot.ma == TRUE) {
      # Plot moving averages
      fig1 <- fig1 + geom_line(aes(x = week, y = count_MA, color = sentiment_MA)) + 
        scale_color_gradient2(name = "Sentiment Moving Average", low = "red", mid = "azure4", high = "green", midpoint = 0)
      fig2 <- fig2 + geom_line(aes(x = week, y = divisiveness_MA), color = "gold")
    }
    ggarrange(fig1, nrow = 2, heights = c(0.75, 0.25))
  } else if (group.by == "day") {
    # Compute statistics
    summary.tibble <- tweet.tibble %>% group_by(date) %>% summarize(mean_sentiment = mean(sentiment), sd_sentiment = sd(sentiment), count = length(datetime), divisiveness = divisiveness_score(sentiment))
    summary.tibble$divisiveness[is.na(summary.tibble$divisiveness)] <- 0
    if (plot.ma == TRUE) {
      # Compute moving averages
      if (ma.type == "weighted") {
        summary.tibble <- summary.tibble %>% mutate(sentiment_MA = WMA(mean_sentiment, ma.n), count_MA = WMA(count, ma.n), divisiveness_MA = WMA(divisiveness, ma.n))
      } else if (ma.type == "exponential") {
        summary.tibble <- summary.tibble %>% mutate(sentiment_MA = EMA(mean_sentiment, ma.n), count_MA = EMA(count, ma.n), divisiveness_MA = EMA(divisiveness, ma.n))
      } else {
        summary.tibble <- summary.tibble %>% mutate(sentiment_MA = SMA(mean_sentiment, ma.n), count_MA = SMA(count, ma.n), divisiveness_MA = SMA(divisiveness, ma.n))
      }
    }
    summary.tibble <- summary.tibble %>% ungroup()
    # Plot tweet counts and average sentiments
    fig1 <- ggplot(summary.tibble, aes(x = date, y = count, fill = mean_sentiment)) + 
      geom_bar(stat = "identity", color = "azure3") + 
      scale_fill_gradient2(name = "Sentiment\nAverage", limits = c(-1,1), low = "red", mid = "white", high = "green", midpoint = 0) +
      ggtitle("Tweets by Day") + 
      ylab("Tweet Count") +
      theme(axis.title.x = element_blank()) 
    # Plot divisiness
    fig2 <- ggplot(summary.tibble, aes(x = date, y = divisiveness)) + 
      geom_bar(fill = "purple", stat = "identity", alpha = 0.8) + 
      geom_hline(yintercept = 0, color = "red", linetype = "dashed") +
      ylab("Divisiveness") +
      xlab("Date") + 
      theme_grey(base_size = 9) 
    if (plot.ma == TRUE) {
      # Plot moving averages
      fig1 <- fig1 + geom_line(aes(x = date, y = count_MA, color = sentiment_MA, label="Tweet Count\nMoving Average")) + 
        scale_color_gradient2(name = "Sentiment\nMoving Average", low = "red", mid = "azure4", high = "green", midpoint = 0) 
      fig2 <- fig2 + geom_line(aes(x = date, y = divisiveness_MA), color = "gold")
    }
    return(ggarrange(fig1, fig2, nrow = 2, heights = c(0.75, 0.25)))
  } else if (group.by == "location"){
    # Compute statistics
    summary.tibble <- tweet.tibble %>% group_by(week) %>% summarize(mean_sentiment = mean(sentiment), sd_sentiment = sd(sentiment), count = length(datetime), divisiveness = divisiveness_score(sentiment))
    summary.tibble$divisiveness[is.na(summary.tibble$divisiveness)] <- 0
    if (plot.ma == TRUE) {
      # Compute moving averages
      if (ma.type == "weighted") {
        summary.tibble <- summary.tibble %>% mutate(sentiment_MA = WMA(mean_sentiment, ma.n), count_MA = WMA(count, ma.n), divisiveness_MA = WMA(divisiveness, ma.n))
      } else if (ma.type == "exponential") {
        summary.tibble <- summary.tibble %>% mutate(sentiment_MA = EMA(mean_sentiment, ma.n), count_MA = EMA(count, ma.n), divisiveness_MA = EMA(divisiveness, ma.n))
      } else {
        summary.tibble <- summary.tibble %>% mutate(sentiment_MA = SMA(mean_sentiment, ma.n), count_MA = SMA(count, ma.n), divisiveness_MA = SMA(divisiveness, ma.n))
      }
    }
    summary.tibble <- summary.tibble %>% ungroup()
    # Plot tweet counts and average sentiments
    fig1 <- ggplot(summary.tibble, aes(x = week, y = count, fill = mean_sentiment)) + 
      geom_bar(stat = "identity", color = "azure3") + 
      scale_fill_gradient2(name = "Sentiment Average", limits = c(-1,1), low = "red", mid = "white", high = "green", midpoint = 0) +
      ggtitle("Tweets by Week") + 
      ylab("Tweet Count") +
      theme(axis.title.x = element_blank())
    if (plot.ma == TRUE) {
      # Plot moving averages
      fig1 <- fig1 + geom_line(aes(x = week, y = count_MA, color = sentiment_MA)) + 
        scale_color_gradient2(name = "Sentiment Moving Average", low = "red", mid = "azure4", high = "green", midpoint = 0)
      fig2 <- fig2 + geom_line(aes(x = week, y = divisiveness_MA), color = "gold")
    }
    ggarrange(fig1, nrow = 2, heights = c(0.75, 0.25))
  }
}


plot_tweet_location <- function(tweet.vectors.df, group.by = "day", compute.sentiment = FALSE, plot.ma = FALSE, ma.n = 5, ma.type = "simple") {
  #########################################################################################################################
  # INPUT:
  #   tweet.vectors.df  : Dataframe of tweets, MUST INCLUDE THE FIELS: `created_at`, `vector_type`.
  #                       FIELD `sentiment` IS OPTIONAL BUT GREATLY SPEEDS UP COMPUTATION.
  #   group.by          : Time frame by which to group tweets, either "day" or "week.
  #   plot.ma           : Whether to plot the moving average of tweet counts, sentiments and divisiveness.
  #   ma.n              : If plotting the moving average, the number of timesteps to be used in the computation.
  #   ma.type           : If plotting the moving average, the type of moving averge to use. Options are: "simple" for SMA; 
  #                       "exponential" for EMA; "weighted" for WMA
  # OUTPUT:
  #   ggplot figure of tweet counts, average sentiment and divisiveness over time.
  #########################################################################################################################
  tweets.df <- tweet.vectors.df[results.df$place.country=="United States",]
  
  if (compute.sentiment == TRUE) {
    tweet.vectors.df$sentiment <- c(0)
    sentiment.vector <- rep(NA, length(tweet.vectors.df$sentiment))
    for (i in 1:length(tweet.vectors.df$sentiment)) {
      tryCatch({
        sentiment.vector[i] <- get_vader(tweet.vectors.df$full_text[i])["compound"]
      }, error = function(e) {
        sentiment.vector[i] <- NA
      })
    }
    tweet.vectors.df$sentiment <- sentiment.vector
    tweet.vectors.df <- tweet.vectors.df[!is.na(sentiment.vector),]
  }
  
  tweets.df$created_at <- as.POSIXct(strptime(tweets.df$created_at, format="%a %b %d %H:%M:%S +0000 %Y", tz="UTC"))
  tweets.df$week <- epiweek(tweets.df$created_at)  # find CDC epidemiological week
  tweets.df$date <- date(tweets.df$created_at)
  tweet.tibble <- tibble(sentiment = tweets.df$sentiment, week = tweets.df$week, date = tweets.df$date, datetime = tweets.df$created_at, location = tweets.df$place.full_name)
  
  
  if (group.by == "week") {
    # Compute statistics
    summary.tibble <- tweet.tibble %>% group_by(week) %>% summarize(mean_sentiment = mean(sentiment), sd_sentiment = sd(sentiment), count = length(datetime), divisiveness = divisiveness_score(sentiment))
    summary.tibble$divisiveness[is.na(summary.tibble$divisiveness)] <- 0
    if (plot.ma == TRUE) {
      # Compute moving averages
      if (ma.type == "weighted") {
        summary.tibble <- summary.tibble %>% mutate(sentiment_MA = WMA(mean_sentiment, ma.n), count_MA = WMA(count, ma.n), divisiveness_MA = WMA(divisiveness, ma.n))
      } else if (ma.type == "exponential") {
        summary.tibble <- summary.tibble %>% mutate(sentiment_MA = EMA(mean_sentiment, ma.n), count_MA = EMA(count, ma.n), divisiveness_MA = EMA(divisiveness, ma.n))
      } else {
        summary.tibble <- summary.tibble %>% mutate(sentiment_MA = SMA(mean_sentiment, ma.n), count_MA = SMA(count, ma.n), divisiveness_MA = SMA(divisiveness, ma.n))
      }
    }
    summary.tibble <- summary.tibble %>% ungroup()
    # Plot tweet counts and average sentiments
    fig1 <- ggplot(summary.tibble, aes(x = week, y = count, fill = mean_sentiment)) + 
      geom_bar(stat = "identity", color = "azure3") + 
      scale_fill_gradient2(name = "Sentiment Average", limits = c(-1,1), low = "red", mid = "white", high = "green", midpoint = 0) +
      ggtitle("Tweets by Week") + 
      ylab("Tweet Count") +
      theme(axis.title.x = element_blank())
    # Plot divisiness
    fig2 <- ggplot(summary.tibble, aes(x = week, y = divisiveness)) + 
      geom_bar(fill = "purple", stat = "identity") + 
      geom_hline(yintercept = 0, color = "red", linetype = "dashed") +
      ylab("Divisiveness") +
      xlab("Date") + 
      theme_grey(base_size = 9) 
    if (plot.ma == TRUE) {
      # Plot moving averages
      fig1 <- fig1 + geom_line(aes(x = week, y = count_MA, color = sentiment_MA)) + 
        scale_color_gradient2(name = "Sentiment Moving Average", low = "red", mid = "azure4", high = "green", midpoint = 0)
      fig2 <- fig2 + geom_line(aes(x = week, y = divisiveness_MA), color = "gold")
    }
    ggarrange(fig1, fig2, nrow = 2, heights = c(0.75, 0.25))
  } 
}

































