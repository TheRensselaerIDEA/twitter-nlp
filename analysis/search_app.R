# load the shiny package
library(shiny)
library(DT)
source("search_appparams.R")



ui <- fluidPage(
  
  introjsUI(),
  
  titlePanel(tagList(
    img(src = "Rensselaer_round.png", height = 60, width = 60),
    
    span("Covid-TWITTER", 
         span(
           introBox(
             actionButton("help", 
                          label = "Help",
                          icon = icon("question"),
                          style="color: #fff; background-color: #B21212; border-color: #B21212"),
             actionButton("github",
                          label = "Code",
                          icon = icon("github"),
                          width = "80px",
                          onclick ="https://github.com/TheRensselaerIDEA/COVID-Twitter",
                          style="color: #fff; background-color: #767676; border-color: #767676"),
             data.step = 6,
             data.intro = "View Code"),
           style = "position:absolute;right:2em;"))),
    windowTitle = "Tweets on Corona"),
  
  hr(),
  
  column(12,
         introBox(title="", width="100%",
                plotlyOutput("clusters")%>% withSpinner(type = 1))
         ),

  
  hr(),
  fluidRow(
    column(8,
           
           tabBox(title = "",
                  tabPanel("Word Cloud",
                           textOutput("Words are larger as they appear more frequently based on the data collection paramaters"),
                           wordcloud2Output("plot") %>% withSpinner(type = 1)),
                  tabPanel("Sentiment Level",
                           plotlyOutput("sentiment") %>% withSpinner(type = 1))

                  
           ),
           
           column(4,
                  
                  
                  introBox(title = "Data",
                           # h4("Adjust data for plots by putting a keyword in the search box below", align="center"),
                           # p("This tweet data is based off of Covid-19 related tweets and can be used to quickly scan for patterns in tweets. The data below contains the tweets that strictly contain the word:", 
                           #   span("mask", style="color:blue"),
                           #   "The dataframe is collected from:",
                           #   span("March 1st to August 1st", style="color:blue")),
                           # p("To compare your findings with CovidMinder data click",
                           #   tags$a(href="https://covidminder.idea.rpi.edu/?tab=state_report_cards", "here.")),
                           DT::dataTableOutput("mytable")
                  )
           ),
           
           hr(),
           
    )
  )
  
  
  
)





server <- function(input, output) {
  results <-do_search(indexname=elasticsearch_index, 
                      rangestart=rangestart,
                      rangeend=rangeend,
                      text_filter=text_filter,
                      semantic_phrase=semantic_phrase,
                      must_have_embedding=TRUE,
                      random_sample=random_sample,
                      resultsize=resultsize,
                      resultfields='"user.screen_name", "user.verified", "user.location", "place.full_name", "place.country", "text", "full_text", "extended_tweet.full_text", "embedding.use_large.primary", "dataset_file", "dataset_entry.annotation.part1.Response", "dataset_entry.annotation.part2-opinion.Response"',
                      elasticsearch_host=elasticsearch_host,
                      elasticsearch_path=elasticsearch_path,
                      elasticsearch_port=elasticsearch_port,
                      elasticsearch_schema=elasticsearch_schema)
  
  
  
  info<-results$df
  
  output$mytable = DT::renderDataTable({
    datatable(info, colnames = c('Tweet' = 6, 'Dataset Origin'= 7, 'Personal Opinion'=8, 'Cure'=9),
              filter="top",
              options = list(
                autoWidth=TRUE,
                columnDefs = list(list(visible=FALSE, targets = c(1,2,3,4,9,10,11,13,14)),
                                  list(width = '1000px', targets = 6)),
                search = list(regex = TRUE, caseInsensitive = TRUE),
                pageLength = 5
              )
    )
  })
  
  
  
  filtered_table <- reactive({
    req(input$mytable_rows_all)
    info[input$mytable_rows_all, ]  
  })
  
  
  output$sentiment<-renderPlotly({
    results$df<-filtered_table()
    # this dataframe contains the tweet text and other metadata
    tweet.vectors.df <- results$df[,c("full_text", "user_screen_name", "user_verified", "user_location", "place.country", "place.full_name", "dataset_file", "dataset_entry.annotation.part1.Response", "dataset_entry.annotation.part2-opinion.Response")]
    
    clean_text <- function(text, for_freq=FALSE) {
      text <- str_replace_all(text, "[\\s]+", " ")
      text <- str_replace_all(text, "http\\S+", "")
      if (isTRUE(for_freq)) {
        text <- tolower(text)
        text <- str_replace_all(text, "’", "'")
        text <- str_replace_all(text, "_", "-")
        text <- str_replace_all(text, "[^a-z1-9 ']", "")
      } else {
        text <- str_replace_all(text, "[^a-zA-Z1-9 `~!@#$%^&*()-_=+\\[\\];:'\",./?’]", "")
      }
      text <- str_replace_all(text, " +", " ")
      text <- trimws(text)
    }
    tweet.vectors.df$full_text <- sapply(tweet.vectors.df$full_text, clean_text)
  
    
    emotions<-get_nrc_sentiment((tweet.vectors.df$full_text))
    
    emo_bar = colSums(emotions)
    emo_sum = data.frame(count=emo_bar, emotion=names(emo_bar))
    emo_sum$emotion = factor(emo_sum$emotion, levels=emo_sum$emotion[order(emo_sum$count, decreasing = TRUE)])
    
    # sentimentscores<-data.frame(colSums(sentiment[,]))
    # names(sentimentscores) <- "Score"
    # sentimentscores <- cbind("sentiment"=rownames(sentimentscores),sentimentscores)
    # rownames(sentimentscores) <- NULL

    # ggplot(data=sentimentscores,aes(x=sentiment,y=Score))+
    #   geom_bar(aes(fill=sentiment),stat = "identity")+
    #   theme(legend.position="none")+
    #   xlab("Sentiments")+ylab("Scores")+
    #   ggtitle("Total sentiment based on scores")+
    #   theme_manual()
    
    plot_ly(emo_sum, x=~emotion, y=~count, type="bar", color=~emotion) %>%
      layout(xaxis=list(title=""), showlegend=FALSE,
             title="No title")
    
  })
  
  
  # output$test <- renderPrint({
  #   filtered_table()
  #   
  # })
  
  output$plot<-renderWordcloud2({
    results$df<-filtered_table()
    # this dataframe contains the tweet text and other metadata
    tweet.vectors.df <- results$df[,c("full_text", "user_screen_name", "user_verified", "user_location", "place.country", "place.full_name", "dataset_file", "dataset_entry.annotation.part1.Response", "dataset_entry.annotation.part2-opinion.Response")]
    
    # this matrix contains the embedding vectors for every tweet in tweet.vectors.df
    tweet.vectors.matrix <- t(simplify2array(results$df[,"embedding.use_large.primary"]))
    
    clean_text <- function(text, for_freq=FALSE) {
      text <- str_replace_all(text, "[\\s]+", " ")
      text <- str_replace_all(text, "http\\S+", "")
      if (isTRUE(for_freq)) {
        text <- tolower(text)
        text <- str_replace_all(text, "’", "'")
        text <- str_replace_all(text, "_", "-")
        text <- str_replace_all(text, "[^a-z1-9 ']", "")
      } else {
        text <- str_replace_all(text, "[^a-zA-Z1-9 `~!@#$%^&*()-_=+\\[\\];:'\",./?’]", "")
      }
      text <- str_replace_all(text, " +", " ")
      text <- trimws(text)
    }
    tweet.vectors.df$full_text <- sapply(tweet.vectors.df$full_text, clean_text)
    tweet.vectors.df$user_location <- sapply(tweet.vectors.df$user_location, clean_text)
    
    
    
    tweet.vectors.df$user_location <- ifelse(is.na(tweet.vectors.df$place.full_name), tweet.vectors.df$user_location, paste(tweet.vectors.df$place.full_name, tweet.vectors.df$place.country, sep=", "))
    tweet.vectors.df$user_location[is.na(tweet.vectors.df$user_location)] <- ""
    tweet.vectors.df$user_location_type <- ifelse(is.na(tweet.vectors.df$place.full_name), "User", "Place")
    tweet.vectors.df$class <- sapply(tweet.vectors.df$dataset_file, function(d) sub(".jsonl", "", d))
    colnames(tweet.vectors.df)[colnames(tweet.vectors.df) == "dataset_entry.annotation.part1.Response"] <- "is_specific_event"
    colnames(tweet.vectors.df)[colnames(tweet.vectors.df) == "dataset_entry.annotation.part2-opinion.Response"] <- "opinion"
    tweet.vectors.df <- tweet.vectors.df[, c("full_text", "user_screen_name", "user_verified", "user_location", "user_location_type", "class", "is_specific_event", "opinion")]
    
    wordcloudtext <- 
      str_c(tweet.vectors.df$full_text, collapse = "") %>%
      str_remove("\\n") %>%                   # remove linebreaks
      str_remove_all("#\\S+") %>%             # Remove any hashtags
      str_remove_all("@\\S+") %>%             # Remove any @ mentions
      removeWords(stopwords("english")) %>%   # Remove common words (a, the, it etc.)
      removeNumbers() %>%
      stripWhitespace() %>%
      removeWords(c("amp"))                   # Final cleanup of other small changes
    
    
    # Convert the data into a summary table
    textCorpus <- 
      Corpus(VectorSource(wordcloudtext)) %>%
      TermDocumentMatrix() %>%
      as.matrix()
    
    textCorpus <- sort(rowSums(textCorpus), decreasing=TRUE)
    textCorpus <- data.frame(word = names(textCorpus), freq=textCorpus, row.names = NULL)
    
    bird <- system.file("examples/t.png",package = "wordcloud2")
    
    # build wordcloud 
    return(wordcloud2(data = textCorpus))
  })
  
  
  
  
  output$clusters<-renderPlotly({
    
    
    # this dataframe contains the tweet text and other metadata
    tweet.vectors.df <- results$df[,c("full_text", "user_screen_name", "user_verified", "user_location", "place.country", "place.full_name", "dataset_file", "dataset_entry.annotation.part1.Response", "dataset_entry.annotation.part2-opinion.Response")]
    
    # this matrix contains the embedding vectors for every tweet in tweet.vectors.df
    tweet.vectors.matrix <- t(simplify2array(results$df[,"embedding.use_large.primary"]))
    
    ###############################################################################
    # Clean the tweet and user location text, and set up tweet.vectors.df 
    # the way we want it by consolidating the location field and computing
    # location type
    ###############################################################################
    
    tweet.vectors.df$user_location <- ifelse(is.na(tweet.vectors.df$place.full_name), tweet.vectors.df$user_location, paste(tweet.vectors.df$place.full_name, tweet.vectors.df$place.country, sep=", "))
    tweet.vectors.df$user_location[is.na(tweet.vectors.df$user_location)] <- ""
    tweet.vectors.df$user_location_type <- ifelse(is.na(tweet.vectors.df$place.full_name), "User", "Place")
    tweet.vectors.df$class <- sapply(tweet.vectors.df$dataset_file, function(d) sub(".jsonl", "", d))
    colnames(tweet.vectors.df)[colnames(tweet.vectors.df) == "dataset_entry.annotation.part1.Response"] <- "is_specific_event"
    colnames(tweet.vectors.df)[colnames(tweet.vectors.df) == "dataset_entry.annotation.part2-opinion.Response"] <- "opinion"
    tweet.vectors.df <- tweet.vectors.df[, c("full_text", "user_screen_name", "user_verified", "user_location", "user_location_type", "class", "is_specific_event", "opinion")]
    
    clean_text <- function(text, for_freq=FALSE) {
      text <- str_replace_all(text, "[\\s]+", " ")
      text <- str_replace_all(text, "http\\S+", "")
      if (isTRUE(for_freq)) {
        text <- tolower(text)
        text <- str_replace_all(text, "’", "'")
        text <- str_replace_all(text, "_", "-")
        text <- str_replace_all(text, "[^a-z1-9 ']", "")
      } else {
        text <- str_replace_all(text, "[^a-zA-Z1-9 `~!@#$%^&*()-_=+\\[\\];:'\",./?’]", "")
      }
      text <- str_replace_all(text, " +", " ")
      text <- trimws(text)
    }
    tweet.vectors.df$full_text <- sapply(tweet.vectors.df$full_text, clean_text)
    tweet.vectors.df$user_location <- sapply(tweet.vectors.df$user_location, clean_text)
    
    k <- 8
    
    ###############################################################################
    # Run K-means on all the tweet embedding vectors
    ###############################################################################
    
    set.seed(300)
    km <- kmeans(tweet.vectors.matrix, centers=k, iter.max=30)
    
    tweet.vectors.df$vector_type <- factor("tweet", levels=c("tweet", "cluster_center", "subcluster_center"))
    tweet.vectors.df$cluster <- as.factor(km$cluster)
    
    #append cluster centers to dataset for visualization
    centers.df <- data.frame(full_text=paste("Cluster (", rownames(km$centers), ") Center", sep=""),
                             user_screen_name="[N/A]",
                             user_verified="[N/A]",
                             user_location="[N/A]",
                             user_location_type = "[N/A]",
                             class = "[N/A]",
                             is_specific_event = "[N/A]",
                             opinion = "[N/A]",
                             vector_type = "cluster_center",
                             cluster=as.factor(rownames(km$centers)))
    tweet.vectors.df <- rbind(tweet.vectors.df, centers.df)
    tweet.vectors.matrix <- rbind(tweet.vectors.matrix, km$centers)
    
    cluster.k <- 8
    
    
    tweet.vectors.df$subcluster <- c(0)
    
    for (i in 1:k){
      print(paste("Subclustering cluster", i, "..."))
      cluster.matrix <- tweet.vectors.matrix[tweet.vectors.df$cluster == i,]
      set.seed(500)
      cluster.km <- kmeans(cluster.matrix, centers=cluster.k, iter.max=30)
      tweet.vectors.df[tweet.vectors.df$cluster == i, "subcluster"] <- cluster.km$cluster
      
      #append subcluster centers to dataset for visualization
      centers.df <- data.frame(full_text=paste("Subcluster (", rownames(cluster.km$centers), ") Center", sep=""),
                               user_screen_name="[N/A]",
                               user_verified="[N/A]",
                               user_location="[N/A]",
                               user_location_type = "[N/A]",
                               class = "[N/A]",
                               is_specific_event = "[N/A]",
                               opinion = "[N/A]",
                               vector_type = "subcluster_center",
                               cluster=as.factor(i),
                               subcluster=rownames(cluster.km$centers))
      tweet.vectors.df <- rbind(tweet.vectors.df, centers.df)
      tweet.vectors.matrix <- rbind(tweet.vectors.matrix, cluster.km$centers)
    }
    tweet.vectors.df$subcluster <- as.factor(tweet.vectors.df$subcluster)
    
    ###############################################################################
    # Compute labels for each cluster and subcluster based on word frequency
    # and identify the nearest neighbors to each cluster and subcluster center
    ###############################################################################
    
    stop_words <- stopwords("english")
    stop_words <- union(stop_words, c(",", ".", "!", "-", "?", "&amp;", "amp"))
    
    get_word_freqs <- function(full_text) {
      word_freqs <- table(unlist(strsplit(clean_text(full_text, TRUE), " ")))
      word_freqs <- cbind.data.frame(names(word_freqs), as.integer(word_freqs))
      colnames(word_freqs) <- c("word", "count")
      word_freqs <- word_freqs[!(word_freqs$word %in% stop_words),]
      word_freqs <- word_freqs[order(word_freqs$count, decreasing=TRUE),]
    }
    
    get_label <- function(word_freqs, exclude_from_labels=NULL, top_k=3) {
      words <- as.character(word_freqs$word)
      exclude_words <- NULL
      if (!is.null(exclude_from_labels)) {
        exclude_words <- unique(unlist(lapply(strsplit(exclude_from_labels, "/"), trimws)))
      }
      label <- paste(setdiff(words, exclude_words)[1:top_k], collapse=" / ")
    }
    
    get_nearest_center <- function(df, mtx, center) {
      df$center_cosine_similarity <- apply(mtx, 1, function(v) (v %*% center)/(norm(v, type="2")*norm(center, type="2")))
      nearest_center <- df[order(df$center_cosine_similarity, decreasing=TRUE),]
      nearest_center <- nearest_center[nearest_center$vector_type=="tweet", c("center_cosine_similarity", "full_text", "user_location")]
    }
    
    master.word_freqs <- get_word_freqs(tweet.vectors.df$full_text)
    master.label <- get_label(master.word_freqs, top_k=6)
    
    clusters <- list()
    for (i in 1:k) {
      cluster.df <- tweet.vectors.df[tweet.vectors.df$cluster == i,]
      cluster.matrix <- tweet.vectors.matrix[tweet.vectors.df$cluster == i,]
      
      cluster.word_freqs <- get_word_freqs(cluster.df$full_text)
      cluster.label <- get_label(cluster.word_freqs, master.label)
      cluster.center <- cluster.matrix[cluster.df$vector_type=="cluster_center",]
      cluster.nearest_center <- get_nearest_center(cluster.df, cluster.matrix, cluster.center)
      
      cluster.subclusters <- list()
      for (j in 1:cluster.k) {
        subcluster.df <- cluster.df[cluster.df$subcluster == j,]
        subcluster.matrix <- cluster.matrix[cluster.df$subcluster == j,]
        
        subcluster.word_freqs <- get_word_freqs(subcluster.df$full_text)
        subcluster.label <- get_label(subcluster.word_freqs, c(master.label, cluster.label))
        subcluster.center <- subcluster.matrix[subcluster.df$vector_type=="subcluster_center",]
        subcluster.nearest_center <- get_nearest_center(subcluster.df, subcluster.matrix, subcluster.center)
        
        cluster.subclusters[[j]] <- list(word_freqs=subcluster.word_freqs, label=subcluster.label, nearest_center=subcluster.nearest_center)
      }
      
      clusters[[i]] <- list(word_freqs=cluster.word_freqs, label=cluster.label, nearest_center=cluster.nearest_center, subclusters=cluster.subclusters)
    }
    
    ###############################################################################
    # Run T-SNE on all the tweets and then again on each cluster to get
    # plot coordinates for each tweet. We output a master plot with all clusters
    # and a cluster plot with all subclusters for each cluster.
    ###############################################################################
    
    set.seed(700)
    tsne <- Rtsne(tweet.vectors.matrix, dims=2, perplexity=25, max_iter=750, check_duplicates=FALSE)
    tsne.plot <- cbind(tsne$Y, tweet.vectors.df)
    colnames(tsne.plot)[1:2] <- c("X", "Y")
    tsne.plot$full_text <- sapply(tsne.plot$full_text, function(t) paste(strwrap(t ,width=60), collapse="<br>"))
    tsne.plot$cluster.label <- sapply(tsne.plot$cluster, function(c) clusters[[c]]$label)
    
    taglist <- htmltools::tagList()
    
    #Master high level plot
    fig <- plot_ly(tsne.plot, x=~X, y=~Y, 
                   text=~paste("Cluster:", cluster, "<br>Class:", class, "<br>IsSpecificEvent:", is_specific_event, "<br>Opinion:", opinion, "<br>Text:", full_text), 
                   color=~cluster.label, type="scatter", mode="markers")
    fig <- fig %>% layout(title=paste("Master Plot:", master.label, "(high level clusters)"), 
                          yaxis=list(zeroline=FALSE), 
                          xaxis=list(zeroline=FALSE))
    # fig <- fig %>% toWebGL()
    # taglist[[1]] <- fig
    
    #  #Cluster plots
    # plot_index <- 2
    # for (i in 1:k) {
    #    print(paste("Plotting cluster", i, "..."))
    #    cluster.matrix <- tweet.vectors.matrix[tsne.plot$cluster == i,]
    # 
    #    set.seed(900)
    #    cluster.tsne <- Rtsne(cluster.matrix, dims=2, perplexity=12, max_iter=500, check_duplicates=FALSE)
    #    cluster.tsne.plot <- cbind(cluster.tsne$Y, tsne.plot[tsne.plot$cluster == i,])
    #    colnames(cluster.tsne.plot)[1:2] <- c("cluster.X", "cluster.Y")
    #    cluster.tsne.plot$subcluster.label <- sapply(cluster.tsne.plot$subcluster, function(c) clusters[[i]]$subclusters[[c]]$label)
    # 
    #    #Cluster plot with regrouped positions by subcluster
    #    fig <- plot_ly(cluster.tsne.plot, x=~cluster.X, y=~cluster.Y,
    #                   text=~paste("Subcluster:", subcluster, "<br>Class:", class, "<br>IsSpecificEvent:", is_specific_event, "<br>Opinion:", opinion, "<br>Text:", full_text),
    #                   color=~subcluster.label, type="scatter", mode="markers")
    #    fig <- fig %>% layout(title=paste('Cluster ', i, ": ", clusters[[i]]$label, " (regrouped by subcluster)", sep=""),
    #                          yaxis=list(zeroline=FALSE),
    #                          xaxis=list(zeroline=FALSE))
    #    #fig <- fig %>% toWebGL()
    #    taglist[[plot_index]] <- fig
    #    plot_index <- plot_index + 1
    #  }
    # 
    #  taglist
    # 
    # 
    
  })
}


# call to shinyApp() which returns the Shiny app
shinyApp(ui = ui, server = server)