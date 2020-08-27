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

if (!require("pracma")) {
  install.packages("pracma")
  library(pracma)
}

if (!require("tidytext")) {
  install.packages("tidytext")
  library(tidytext)
}

if (!require("stringr")) {
  install.packages("stringr")
  library(stringr)
}

if (!require("plotly")) {
  install.packages("plotly")
  library(plotly)
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
  n <- length(x)
  x[x < -0.05] <- -1
  x[x > 0.05] <- 1
  x[x > -0.05 & x < 0.05] <- 0
  if (n > 3) {
    skew.mean <- moments::skewness(x) 
    kurt.mean <- moments::kurtosis(x)
    skew.var <- 6 * n * ( n - 1) / ((n - 2) * (n + 1) * (n + 2))
    skew.squared.var <- skew.var^2 + 2 * skew.var * skew.mean^2
    kurt.var <- 4 * skew.var * (n^2 - 1) / ((n - 3) * (n + 5))
    BC.mean <- (skew.mean^2 + 1) / kurt.mean # compute Sarle's BC
    BC.var <- skew.squared.var / kurt.mean^2 + kurt.var * (skew.mean^2 + 1)^2 / kurt.mean^4
    phi <- 5/9
    Z <- abs(BC.mean - phi) / sqrt(BC.var)
    w <- pracma::erf(Z / sqrt(2))
    BCc <- w * BC.mean + (1 - w) * phi
    return(pracma::logit(BCc) - pracma::logit(phi))
  } else {
    return(0)
  }
}

helper_positive_keywords <- function(full_text, sentiment, stop_words, top_k=3, max_lookahead=50) {
  ###################################################################################################
  # Find top keywords from the top sentiment quartile of given tweets 
  #
  # INPUT:
  #   full_text     : vector of tweet texts
  #   sentiment     : vector of tweet sentiments
  #   stop_words    : data frame of stop words (most common is output from `data(stop_words)`)
  #   top_k         : integer equal to number of top keywords to return
  #   max_lookahead : integer equal to maximum number of top frequency words to consider as keywords
  #                   (this avoids considering words that only pop up in the quartiles by chance as 
  #                     keywords in small samples).
  #                   To consider all words as possible keywords, pass in `NULL`
  # OUTPUT:
  #   string containing top k positive keywords from `full_text` separated by slashes ("/")
  ###################################################################################################
  tibble.df <- tibble(full_text = full_text, sentiment = sentiment)
  corpus.df <- tibble.df %>%  # build corpus of all words
    unnest_tokens(word, full_text) %>% 
    anti_join(stop_words, by = "word") %>%
    dplyr::count(word) %>%
    mutate(prob = n / sum(n))
  tibble.df<- tibble.df %>% mutate(quantile = ntile(sentiment, 4))
  top.pos.tweets <- tibble.df[tibble.df$quantile == 4,] # get 4th sentiment quartile tweets
  pos.words.df <- top.pos.tweets %>% # get words from the 4th quartile
    unnest_tokens(word, full_text) %>% 
    anti_join(stop_words, by = "word") %>%
    dplyr::count(word) %>%
    mutate(prob_pos = n / sum(n)) 
  
  # Take top frequency words in the 4th quartile and rank them according to keyword score
  if (is.null(max_lookahead)) {
    max_lookahead <- dim(pos.words.df)[1]
  } 
  pos.words.df <- pos.words.df[1:(min(dim(pos.words.df)[1], max_lookahead)),] %>%  
    inner_join(corpus.df, by = "word") %>%
    mutate(score = prob_pos * log(prob_pos / prob)) %>%
    dplyr::arrange(desc(score))
  top_k <- min(top_k, dim(pos.words.df)[1]) # get top keywords
  return(paste((pos.words.df[1:top_k,])$word, collapse=" / "))
}

helper_negative_keywords <- function(full_text, sentiment, stop_words, top_k=3, max_lookahead=50) {
  ###################################################################################################
  # Find top keywords from the bottom sentiment quartile of given tweets 
  #
  # INPUT:
  #   full_text     : vector of tweet texts
  #   sentiment     : vector of tweet sentiments
  #   stop_words    : data frame of stop words (most common is output from `data(stop_words)`)
  #   top_k         : integer equal to number of top keywords to return
  #   max_lookahead : integer equal to maximum number of top frequency words to consider as keywords
  #                   (this avoids considering words that only pop up in the quartiles by chance as 
  #                     keywords in small samples).
  #                   To consider all words as possible keywords, pass in `NULL`
  # OUTPUT:
  #   string containing top k negative keywords from `full_text` separated by slashes ("/")
  ###################################################################################################
  tibble.df <- tibble(full_text = full_text, sentiment = sentiment)
  corpus.df <- tibble.df %>% # build corpus of all words
    unnest_tokens(word, full_text) %>% 
    anti_join(stop_words, by = "word") %>%
    dplyr::count(word) %>%
    mutate(prob = n / sum(n))
  tibble.df<- tibble.df %>% mutate(quantile = ntile(sentiment, 4))
  top.neg.tweets <- tibble.df[tibble.df$quantile == 1,] # get 1st sentiment quartile tweets
  neg.words.df <- top.neg.tweets %>% # get words from the 1st quartile
    unnest_tokens(word, full_text) %>% 
    anti_join(stop_words, by = "word") %>%
    dplyr::count(word) %>%
    mutate(prob_neg = n / sum(n)) 
  
  # Take top frequency words in the 1st quartile and rank them according to keyword score
  if (is.null(max_lookahead)) {
    max_lookahead <- dim(pos.words.df)[1]
  } 
  neg.words.df <- neg.words.df[1:(min(dim(neg.words.df)[1], max_lookahead)),] %>%
    inner_join(corpus.df, by = "word") %>%
    mutate(score = prob_neg * log(prob_neg / prob)) %>%
    dplyr::arrange(desc(score))
  top_k <- min(top_k, dim(neg.words.df)[1]) # get top keywords
  return(paste((neg.words.df[1:top_k,])$word, collapse=" / "))
}

helper_VADER_class <- function(sentiment) {
  #################################################################################################
  # Compute the sentiment class from a VADER score using the threshholds of -0.05 for negative
  # and 0.05 for positive as suggested by the original authors of the algorithm.
  # 
  # INPUT:
  #   sentiment : vector of VADER sentiment scores
  # OUTPUT:
  #   class.vec : vector of VADER sentiment classes
  #
  # Hutto, Clayton J., and Eric Gilbert. "Vader: A parsimonious rule-based model for sentiment 
  # analysis of social media text." In Eighth international AAAI conference on weblogs and social 
  # media. 2014.
  #################################################################################################
  class.vec <- sentiment
  for (i in 1:length(sentiment)) {
    if (sentiment[i] < -0.05) {
      class.vec[i] <- "NEGATIVE"
    } else if (sentiment[i] > 0.05) {
      class.vec[i] <- "POSITIVE"
    } else {
      class.vec[i] <- "NEUTRAL"
    }
  }
  return(class.vec)
}

plot_tweet_timeseries <- function(tweet.vectors.df, group.by = "week", sentiment.col = NA, title = NA, compute.sentiment = FALSE, keyword_max_lookahead=50) {
  #########################################################################################################################
  # Return plot of tweet counts, average sentiments, divisiveness and top and bottomsentiment quartile keywords over time.
  #
  # INPUT:
  #   tweet.vectors.df      : Dataframe of tweets, MUST INCLUDE THE FIELS: `created_at`, `vector_type`.
  #   group.by              : Time frame by which to group tweets, either "day" or "week.
  #   sentiment.col         : String for the name of the dataframe column holding sentiment scores.
  #                             If NA, then default string "sentiment" will be attempted.
  #   title                 : Desired plot title
  #   compute.sentiment     : Whether to manually go through the dataframe and compute sentiment scores for all tweets.
  #   keyword_max_lookahead : Argument `max_lookahead` to be passed to `helper_negative_keywords` and 
  #                             `helper_positive_keywords` when finding weekly top and bottom sentiment quartile keywords.
  #                             To consider all words as possible keywords, pass in `NULL`.
  # OUTPUT:
  #   plot_ly figure of tweet counts, average sentiment, divisiveness and sentiment quartile keywords over time.
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
  if (is.na(sentiment.col)) {
    tweet.tibble <- tibble(
      full_text = tweets.df$full_text, 
      sentiment = tweets.df$sentiment, 
      week = tweets.df$week, 
      date = tweets.df$date, 
      datetime = tweets.df$created_at)
  } else {
    tweet.tibble <- tibble(
      full_text = tweets.df$full_text, 
      sentiment = tweets.df[[sentiment.col]], 
      week = tweets.df$week, 
      date = tweets.df$date, 
      datetime = tweets.df$created_at)
  }
  if (group.by == "week") {
    # Compute statistics
    data("stop_words")
    summary.tibble <- tweet.tibble %>% 
      group_by(week) %>% 
      summarise(
        mean_sentiment = mean(sentiment), 
        sd_sentiment = sd(sentiment), 
        count = length(datetime), 
        divisiveness = divisiveness_score(sentiment),
        top_pos_keywords = helper_positive_keywords(full_text, 
                                                    sentiment, 
                                                    stop_words = stop_words, 
                                                    max_lookahead = keyword_max_lookahead),
        top_neg_keywords = helper_negative_keywords(full_text, 
                                                    sentiment, 
                                                    stop_words = stop_words, 
                                                    max_lookahead = keyword_max_lookahead),
        .groups = 'drop'
      )
    summary.tibble <- summary.tibble %>% ungroup()
    if (is.na(title)) {
      title.name <- paste("Tweets by", str_to_title(group.by))
    } else {
      title.name <- title
    }
    # Plot tweet counts and average sentiments bar plot
    fig1 <- ggplot(summary.tibble, aes(x = week, y = count, fill = mean_sentiment)) + 
      geom_bar(stat = "identity", color = "azure3") + 
      scale_fill_gradient2(name = "Sentiment Average", limits = c(-1,1), low = "#D55E00", mid = "white", high = "#0072B2", midpoint = 0) +
      ylab("Tweet Count") +
      theme(axis.title.x = element_blank())
    # Plot divisiness
    fig2 <- ggplot(summary.tibble, aes(x = week, y = divisiveness)) + 
      geom_bar(fill = "#CC79A7", stat = "identity") + 
      geom_hline(yintercept = 0, color = "red", linetype = "dashed") +
      ylab("Divisiveness") +
      xlab("CDC Epidemiological Week") + 
      theme_grey(base_size = 9) 
    # Plot tweet sentiment line plot with sentiment distribution violin plots and top and bottom sentiment quartile keywords
    fig3 <- ggplot(data = summary.tibble, aes(x = week, y = mean_sentiment)) + 
      geom_line() +
      geom_linerange(aes(ymin = mean_sentiment - sd_sentiment, ymax = mean_sentiment + sd_sentiment)) +
      geom_point(aes(color = factor(helper_VADER_class(mean_sentiment)), 
                     text = paste("Week :", week,
                                  "<br>Sentiment Class :", helper_VADER_class(mean_sentiment),
                                  "<br>Avg. Sentiment :", mean_sentiment,
                                  "<br>Top Pos. Keywords :", top_pos_keywords,
                                  "<br>Top Neg. Keywords :", top_neg_keywords))) +
      scale_color_manual(values = setNames(c("#D55E00", "#000000", "#0072B2"), 
                                           c("NEGATIVE", "NEUTRAL", "POSITIVE"))) +
      geom_violin(data = tweet.tibble, aes(x = week, y = sentiment, group = week), fill = NA) +
      ylab("Avg Tweet Sentiment") +
      xlab("CDC Epidemiological Week") + 
      theme(legend.position = "none")
    fig1 <- ggplotly(fig1)
    fig2 <- ggplotly(fig2)
    fig3 <- ggplotly(fig3)
    return(subplot(fig1, fig2, fig3, 
                   nrows = 3, 
                   heights = c(0.4, 0.2, 0.4), 
                   shareX = TRUE, 
                   titleY = TRUE) %>%
             layout(title = title.name))
  } else if (group.by == "day") {
    # Compute statistics
    data("stop_words")
    summary.tibble <- tweet.tibble %>% 
      group_by(date) %>% 
      summarise(
        mean_sentiment = mean(sentiment), 
        sd_sentiment = sd(sentiment), 
        count = length(datetime), 
        divisiveness = divisiveness_score(sentiment),
        top_pos_keywords = helper_positive_keywords(full_text, 
                                                    sentiment, 
                                                    stop_words = stop_words, 
                                                    max_lookahead = keyword_max_lookahead),
        top_neg_keywords = helper_negative_keywords(full_text, 
                                                    sentiment, 
                                                    stop_words = stop_words, 
                                                    max_lookahead = keyword_max_lookahead),
        .groups = 'drop'
      )
    summary.tibble <- summary.tibble %>% ungroup()
    if (is.na(title)) {
      title.name <- paste("Tweets by", str_to_title(group.by))
    } else {
      title.name <- title
    }
    # Plot tweet counts and average sentiments bar plot
    fig1 <- ggplot(summary.tibble, aes(x = date, y = count, fill = mean_sentiment)) + 
      geom_bar(stat = "identity", color = "azure3") + 
      scale_fill_gradient2(name = "Sentiment Average", limits = c(-1,1), low = "#D55E00", mid = "white", high = "#0072B2", midpoint = 0) +
      ggtitle(title.name) + 
      ylab("Tweet Count") +
      theme(axis.title.x = element_blank())
    # Plot divisiness
    fig2 <- ggplot(summary.tibble, aes(x = date, y = divisiveness)) + 
      geom_bar(fill = "#CC79A7", stat = "identity") + 
      geom_hline(yintercept = 0, color = "red", linetype = "dashed") +
      ylab("Divisiveness") +
      xlab("Date") + 
      theme_grey(base_size = 9) 
    # Plot tweet sentiment line plot with sentiment distribution violin plots and top and bottom sentiment quartile keywords
    fig3 <- ggplot(data = summary.tibble, aes(x = date, y = mean_sentiment)) + 
      geom_line() +
      geom_linerange(aes(ymin = mean_sentiment - sd_sentiment, ymax = mean_sentiment + sd_sentiment)) +
      geom_point(aes(color = factor(helper_VADER_class(mean_sentiment)), 
                     text = paste("date :", date,
                                  "<br>Sentiment Class :", helper_VADER_class(mean_sentiment),
                                  "<br>Avg. Sentiment :", mean_sentiment,
                                  "<br>Top Pos. Keywords :", top_pos_keywords,
                                  "<br>Top Neg. Keywords :", top_neg_keywords))) +
      scale_color_manual(values = setNames(c("#D55E00", "#000000", "#0072B2"), 
                                           c("NEGATIVE", "NEUTRAL", "POSITIVE"))) +
      geom_violin(data = tweet.tibble, aes(x = date, y =helper_VADER_class(sentiment), group = date), fill = NA) +
      ggtitle(paste("Sentiment by", group.by)) + 
      ylab("Avg Tweet Sentiment") +
      xlab("Date") + 
      theme(legend.position = "none")
    fig1 <- ggplotly(fig1)
    fig2 <- ggplotly(fig2)
    fig3 <- ggplotly(fig3)
    return(subplot(fig1, fig2, fig3, 
                   nrows = 3, 
                   heights = c(0.4, 0.2, 0.4), 
                   shareX = TRUE, 
                   titleY = TRUE) %>%
             layout(title = title.name))
  }
}

plot_keyword_timeseries <- function(full_text, corpus_text, dates, title = NA, top_k=5, max_lookahead=100) {
  #########################################################################################################################
  # Return plot of weekly counts and trends for the top keywords in `full_text`, with `corpus_text` as a reference
  #
  # INPUT:
  #   full_text     : vector of tweet texts of interest.
  #   corpus_tet    : vector of reference tweet texts, drawn from a superset of `full_text` to be used as reference
  #   dates         : dates for tweets of interest from `full_text`.
  #                   TWO POSSIBLE INPUT TYPES:
  #                     - `created_at` string output from elastic search
  #                     - a POSIXlt or POSIXct date 
  #   title         : [string] desired title for plot
  #   top_k         : integer equal to the number of top keywords to be considered
  #   max_lookahead : integer equal to the number of top frequency words from `full_text` to be considered possible 
  #                     keywords. Useful for small samples. TO CONSIDER ALL WORDS AS POSSIBLE KEYWORDS, PASS IN `NULL`
  # OUTPUT:
  #   plot_ly figure of weekly keyword counts and trends
  #########################################################################################################################
  if (!is.POSIXt(dates)) {
    dates <- as.POSIXct(strptime(dates, format="%a %b %d %H:%M:%S +0000 %Y", tz="UTC"))
  }
  data("stop_words")
  
  corpus.df <- tibble(tweet = corpus_text) %>% 
    unnest_tokens(word, tweet) %>% 
    anti_join(stop_words, by = "word") %>%
    dplyr::count(word) %>%
    mutate(prob = n / sum(n))
  
  tweet.tibble <- tibble(tweet = full_text, week = epiweek(dates))
  words.df <- tweet.tibble %>%
    unnest_tokens(word, tweet) %>% 
    anti_join(stop_words, by = "word") %>%
    dplyr::count(word, sort = TRUE) %>%
    mutate(prob_subset = n / sum(n)) 
  
  if (is.null(max_lookahead)) {
    max_lookahead <- dim(words.df)[1]
  }
  
  words.df <- words.df[1:max_lookahead,] %>%
    inner_join(corpus.df, by = "word") %>%
    mutate(score = prob_subset * log(prob_subset / prob)) %>%
    dplyr::arrange(desc(score))
  words.df <- words.df[1:top_k,]
  
  keywords.trend.df <- tweet.tibble %>%
    unnest_tokens(word, tweet) %>%
    inner_join(words.df, by = "word") %>%
    group_by(week) %>%
    dplyr::count(word)
  
  title.str <- title
  if (is.na(title)) {
    title.str <- "Weekly Keyword Trends"
  }
  fig1 <- ggplot(keywords.trend.df, aes(x = week, y = n, color = word)) + 
    geom_smooth(se = FALSE, method = "loess") + 
    ylab("Keyword Count / Week") + 
    xlab("CDC Epidemiological Week") + 
    scale_color_discrete("Keyword")
  
  keywords.trend.df <- keywords.trend.df %>%
    ungroup() %>%
    group_by(word) %>%
    mutate(n = n / max(n))
  
  fig2 <- ggplot(keywords.trend.df, aes(x = week, y = n, color = word)) + 
    geom_smooth(se = FALSE, method = "loess") + 
    xlab("CDC Epidemiological Week") + 
    ylab("Normalized Word Count / Week") +
    theme(legend.title = element_blank())
  
  fig1 <- ggplotly(fig1)
  fig2 <- ggplotly(fig2)
  fig <- subplot(fig1, fig2, nrows = 2, shareX = TRUE, titleY = TRUE) %>%
    layout(title = title.str)
  return(fig)
  
}

plot_divisiveness <- function(tweet.vectors.df, group.by = "week", sentiment.col = NA, title = NA) {
  tweets.df <- tweet.vectors.df %>% filter(vector_type == "tweet")
  tweets.df$created_at <- as.POSIXct(strptime(tweets.df$created_at, format="%a %b %d %H:%M:%S +0000 %Y", tz="UTC"))
  tweets.df$week <- epiweek(tweets.df$created_at)  # find CDC epidemiological week
  # Compute statistics
  data("stop_words")
  summary.tibble <- tweets.df %>% 
    group_by(week)
  if (is.na(sentiment.col)) {
    summary.tibble <- summary.tibble %>% 
      summarise(
        divisiveness = divisiveness_score(sentiment),
        .groups = 'drop'
      )
  } else {
    summary.tibble <- summary.tibble %>% 
      summarise(
        divisiveness = divisiveness_score(!!sym(sentiment.col)),
        .groups = 'drop'
      )
  }
  summary.tibble <- summary.tibble %>% ungroup()
  if (is.na(title)) {
    title.name <- paste("Divisiveness by", str_to_title(group.by))
  } else {
    title.name <- title
  }
  # Plot divisiness
  fig <- ggplot(summary.tibble, aes(x = week, y = divisiveness)) + 
    geom_bar(aes(fill = factor(divisiveness < 0)), stat = "identity") + 
    ylab("Divisiveness") +
    xlab("CDC Epidemiological Week") +
    ggtitle(title.name) +
    theme(legend.position = "none")
  return(fig)
}

