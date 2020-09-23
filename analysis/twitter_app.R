if (!require("ggplot2")) {
  install.packages("ggplot2")
  library(ggplot2)
}

if (!require("png")) {
  install.packages("png")
  library(png)
}


if (!require("magick")) {
  install.packages("magick")
  library(magick)
}

if (!require("knitr")) {
  install.packages("knitr")
  library(knitr)
}

if(!require('dplyr')) {
  install.packages("dplyr")
  library(dplyr)
}

if(!require('stringr')) {
  install.packages("stringr")
  library(stringr)
}

if(!require('plotly')) {
  install.packages("plotly")
  library(plotly)
}

if (!require("kableExtra")) {
  install.packages("kableExtra")
  library(kableExtra)
}

if (!require("syuzhet")) {
  install.packages("syuzhet")
  library(syuzhet)
}
if (!require("wordcloud2")) {
  install.packages("wordcloud2")
  library(wordcloud2)
}

if (!require("tidytext")) {
  install.packages("tidytext")
  library(tidytext)
}

#if (!require("tm")) {
#  install.packages("tm")
#  library(tm)
#}

if (!require("ggrepel")) {
  install.packages("ggrepel")
  library(ggrepel)
}

if (!require("wordcloud")) {
  install.packages("wordcloud")
  library(wordcloud)
}

# load the shiny package
library(shiny)
library(rintrojs)
library(shinycssloaders)
library(shinydashboard)
library(wordcloud2)
source("text_helpers.R")
source("plot_helpers.R")
source("plot_tweet_timeseries.R")

load("/data/COVID-Twitter/analysis/snapshots/final_shiny.Rdata")

cluster_options <- function() {
  options=list()
  for (i in 1:k) {
    cluster_label <- format_label(clusters[[i]]$label, i, include_prefix=TRUE)
    options[cluster_label] = i
  }
  return(options)
}

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
  
  fluidRow(
    column(12,
           
           tabBox(title="",
                  width=8,
                  tabPanel("Master Plot",
                           uiOutput("masterplot") %>% withSpinner(type = 1))
           ),
           column(3,
                  introBox(
                    #wordcloud2Output("wordcloud") %>% withSpinner(type = 1)
                    
                  )
           )
           
    )
    
  ),
  
  
  
  
  
  hr(),
  fluidRow(
    column(12,
           
           tabBox(title = "",
                  width=8,
                  tabPanel("Subcluster Plot",
                           textOutput("Cluster Plot"),
                           uiOutput("subplot") %>% withSpinner(type = 1)),
                  tabPanel("Sentiment Level Over Time",
                           plotOutput("sentiment") %>% withSpinner(type = 1))
                  
                  
           ),
           
           column(3,
                  
                  
                  introBox(
                    selectInput("cluster", label = h4("Cluster"),
                                choices=cluster_options(),
                                selected=1,
                                width="100%")
                    
                  )
           )
           
    )
  ),
  HTML(load_tweet_viewer())
  
  
)






server <- function(input, output) {
  title <- paste("Master Plot:", master.label, "(primary clusters)")
  output$masterplot<-renderUI({
    div(
      plot_tweets(master.tsne.plot, 
                  title=title, 
                  sentiment_threshold=sentiment_threshold,
                  type="clusters", 
                  mode=plot_mode, 
                  webGL=TRUE)
    )
  })
  
  selected_cluster<-reactive({
    return (as.integer(input$cluster))
  })
  
  
  
  
  output$subplot<-renderUI({
    selected_cluster <- selected_cluster()
    title <- paste('Cluster', selected_cluster, ":", clusters[[selected_cluster]]$label, "(regrouped by subcluster)")
    div (
      plot_tweets(clusters[[selected_cluster]]$tsne.plot, 
                  title=title, 
                  sentiment_threshold=sentiment_threshold,
                  type="subclusters_regrouped", 
                  mode=plot_mode, 
                  webGL=FALSE)
    )
  })
  
  output$sentiment<-renderPlot({
    selected_cluster<-selected_cluster()
    continuous_sentiment_barplot(tweet.vectors.df[tweet.vectors.df$cluster==selected_cluster,], 
                                 sentiment_threshold)
  })
  
  output$wordcloud<-renderWordcloud2({
    wordcloudtext <- 
      str_c(tweet.vectors.df$full_text, collapse = "") %>%
      str_remove("\\n") %>%                   # remove linebreaks
      str_remove_all("#\\S+") %>%             # Remove any hashtags
      str_remove_all("@\\S+") %>%             # Remove any @ mentions
      removeWords(stop_words) %>%    # Remove common words (a, the, it etc.)
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
    
    # build wordcloud 
    return(wordcloud2(data = textCorpus))
  })
  
}


# call to shinyApp() which returns the Shiny app
shinyApp(ui = ui, server = server)