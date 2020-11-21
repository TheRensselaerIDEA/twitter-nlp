#
# This is a Shiny web application. You can run the application by clicking
# the 'Run App' button above.
#
# Find out more about building applications with Shiny here:
#
#    http://shiny.rstudio.com/
#
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

if (!require('dplyr')) {
    install.packages("dplyr")
    library(dplyr)
}

if (!require('stringr')) {
    install.packages("stringr")
    library(stringr)
}

if (!require('plotly')) {
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

if (!require("ggrepel")) {
    install.packages("ggrepel")
    library(ggrepel)
}

if (!require("wordcloud")) {
    install.packages("wordcloud")
    library(wordcloud)
}

if (!require("shinyjs")) {
    install.packages("shinyjs")
    library(shinyjs)
}



setwd("/home/zhangh20/COVID-Twitter/analysis")
source("Elasticsearch.R")
source("Summarizer.R")
source("general_helpers.R")
source("text_helpers.R")
source("plot_helpers.R")
source("plot_tweet_timeseries.R")
source("Shiny_twitter_quotes.R")
library(shiny)

Building = TRUE

# Define UI for COVID19 Twitter
ui <- fixedPage(
    titlePanel("COVID-19 Twitter Analysis"),
    sidebarLayout(
        sidebarPanel(
            ############################################################################################sidebarPanel
            textInput("phrase", "Text input:", "There is no cure for COVID-19."),
            selectInput(
                "index",
                "data index:",
                c(
                    "coronavirus-masks" = "coronavirus-data-masks",
                    "coronavirus-pubhealth" = "coronavirus-data-pubhealth-quotes"
                )
            ),
            conditionalPanel(
                condition = "input.index == 'coronavirus-data-pubhealth-quotes'",
                textInput("asOne", "Text Aspect01 input:", "We should develop herd immunity"),
                textInput(
                    "asTwo",
                    "Text ASpect02 input:",
                    "We should quarantine until there is a vaccine"
                )
            ),
            sliderInput(
                "ResultSize",
                "Number of Result (Result Size)",
                min = 500,
                max = 10000,
                value = 1000
            ),
            sliderInput(
                "kValue",
                "number of clusters (k neraest neighbours)",
                min = 1,
                max = 10,
                value = 3
            ),
            dateInput(
                "TimeStart",
                "Date from",
                value = "2020-03-01",
                min = as.Date("2020-03-01"),
                max = as.Date("2020-08-01")
            ),
            dateInput(
                "TimeEnd",
                "Date To",
                value = "2020-07-01",
                min = as.Date("2020-04-01"),
                max = as.Date("2020-08-01")
            ),
            # "AnalysisOutput"
            checkboxInput(
                "discrete_sentiment_lines",
                "Tweets Counts by Sentiment",
                value = FALSE
            ),
            checkboxInput(
                "continuous_sentiment_barplot",
                "Sentiment overtime (barplot)",
                value = FALSE
            ),
            actionButton("action", "Analysis")
            ###########################################################################################sidebarPanel
        ),
        mainPanel(
            ###########################################################################################mainPanelBegin
            uiOutput("KMeans"),
            conditionalPanel(
                condition = "input.discrete_sentiment_lines == TRUE",
                plotOutput("discrete_sentiment_lines")
            ),
            conditionalPanel(
                condition = "input.continuous_sentiment_barplot == TRUE",
                plotOutput("continuous_sentiment_barplot")
            ),
            plotOutput("cluster_sentiments_plots")
            # fluidRow(
            #     column(9,
            #            'Subcluster',
            #            uiOutput("SubCluster")
            #            ),
            #     column(3,
            #            'ListofClusters',
            #            tableOutput("KClusters")
            #            )
            # ),
            
            
            ###########################################################################################mainPanelEnd
        ),
        position = c("left", "right"),
        fluid = FALSE
    )
    
    # # Application title
    # titlePanel("COVID-19 Twitter Analysis"),
    # fixedRow(
    #     column(8,
    #            "set and K means picture ",
    #            fixedRow(
    #                     column(
    #                             12,"the setting pannel",
    #                             wellPanel(
    #                                 textInput("phrase", "Text input:", "There is no cure for COVID-19."),
    #                                 selectInput("index", "data index:",
    #                                             c("coronavirus-masks" = "coronavirus-data-masks",
    #                                               "coronavirus-pubhealth" = "coronavirus-data-pubhealth-quotes")),
    #                                 conditionalPanel(
    #                                     condition= "input.index == 'coronavirus-data-pubhealth-quotes'",
    #                                     textInput("asOne", "Text Aspect01 input:", "We should develop herd immunity"),
    #                                     textInput("asTwo", "Text ASpect02 input:", "We should quarantine until there is a vaccine")
    #                                 ),
    #                                 sliderInput("ResultSize","Number of Result (Result Size)",min=500,max=10000,value=1000),
    #                                 sliderInput("kValue","number of clusters (k neraest neighbours)",min=1,max=10,value=3),
    #                                 dateInput("TimeStart","Date from",value = "2020-03-01",min = as.Date("2020-03-01"),max =as.Date("2020-08-01")),
    #                                 dateInput("TimeEnd","Date To",value = "2020-07-01",min = as.Date("2020-04-01"),max =as.Date("2020-08-01")),
    #                                 actionButton("action", "Analysis")
    #                             )
    #                     )
    #           ),
    #            fixedRow(
    #                     column(
    #                             12,"the pciture of pannel",
    #                             uiOutput("KMeans")
    #                     )
    #             )
    #     ),
    #     column(4,
    #            "the list of k means picture",
    #            fixedRow(
    #                wellPanel(
    #
    #                    tableOutput("KClusters")
    #                )
    #            )
    #     )
    # )
)

# Define server logic required to draw a histogram
server <- function(input, output) {
   
    
    
    observeEvent(input$index, {
        print("add")
        print(input$index)
        if (input$index != "coronavirus-data-pubhealth-quotes")
        {
            shinyjs::hide(id = "asOne")
            shinyjs::hide(id = "asTwo")
        }
        else
        {
            shinyjs::show(id = "asOne")
            shinyjs::show(id = "asTwo")
        }
    })
    
    observeEvent(input$action, {
        print("Input Loading")
        index <- input$index
        semantic_phrase <- input$phrase
        aspect1 <- input$asOne
        aspect2 <- input$asTwo
        rangestart <- paste(input$TimeStart, "00:00:00")
        rangeend <- paste(input$TimeEnd, "00:00:00")
        kValue <- input$kValue
        labelJDG <- TRUE
        ResultSize <- input$ResultSize
        if (isTRUE(Building))
        {
            print("Running the Search")
            if (index == "coronavirus-data-masks" ||
                (aspect1 == "" || aspect2 == ""))
            {
                labelJDG <- TRUE
                print("Tweet V2")
                tmpResult = TweetSearchVersionTwo(
                    index,
                    semantic_phrase,
                    aspect1,
                    aspect2,
                    rangestart,
                    rangeend,
                    kValue,
                    ResultSize
                )
                tweet.vectors.df <- tmpResult$tweet.vectors.df
                master.tsne.plot <- tmpResult$master.tsne.plot
            }
            else
            {
                labelJDG <- FALSE
                print("Tweet V1")
                tmpResult = TweetSearch(
                    semantic_phrase,
                    aspect1,
                    aspect2,
                    rangestart,
                    rangeend,
                    kValue,
                    ResultSize
                )
                tweet.vectors.df <- tmpResult$tweet.vectors.df
                master.tsne.plot <- tmpResult$master.tsne.plot
            }
            
            
        }
        #------------------------------------------------------------------------------
        title <-
            paste0("Master Plot: tweets similar to '", semantic_phrase , "'")
        sentiment_threshold <- 0.05
        plot_mode = "2d"
        
        print("Plotting")
        if (isTRUE(labelJDG))
        {
            output$KMeans <- renderUI({
                div(
                    plot_tweets(
                        master.tsne.plot,
                        title = title,
                        sentiment_threshold = sentiment_threshold,
                        type = "clusters",
                        mode = plot_mode,
                        webGL = TRUE
                    )
                )
            })
        }
        else
        {
            output$KMeans <- renderUI({
                div(
                    plot_tweets(
                        master.tsne.plot,
                        title = title,
                        sentiment_threshold = sentiment_threshold,
                        type = "clusters",
                        mode = plot_mode,
                        webGL = TRUE,
                        xlabel = aspect1,
                        ylabel = aspect2
                    )
                )
            })
        }
        
        # output$KMeans <- renderUI(tagList)
        print(unique(master.tsne.plot$cluster.label))
        output$KClusters <-
            renderTable({
                unique(master.tsne.plot$cluster.label)
            })
        output$discrete_sentiment_lines <- renderPlot({discrete_sentiment_lines(tweet.vectors.df, 0.05)})
        output$continuous_sentiment_barplot <- renderPlot({continuous_sentiment_barplot(tweet.vectors.df,0.05)})
        # output$cluster_sentiments_plots <- renderPlot({cluster_sentiments_plots(tweet.vectors.df,0.05,kValue)})
        # if(input$discrete_sentiment_lines)
        # {
        #     output$discrete_sentiment_lines <- renderPlot({discrete_sentiment_lines(tweet.vectors.df, 0.05)})
        # }
        # if(input$continuous_sentiment_barplot)
        # {
        #     output$continuous_sentiment_barplot <- renderPlot({continuous_sentiment_barplot(tweet.vectors.df,0.05)})
        # }
        
        
        print("Done")
        #------------------------------------------------------------------------------
    })
    
    # observeEvent(input$discrete_sentiment_lines,{
    #     print(input$discrete_sentiment_lines)
    #     print(search)
    #     if(isTRUE(input$discrete_sentiment_lines) && search)
    #     {
    #         output$discrete_sentiment_lines <- renderPlot({discrete_sentiment_lines(tweet.vectors.df, 0.05)})
    #     }
    # }, ignoreInit = TRUE)
}

# Run the application
shinyApp(ui = ui, server = server)

#########################################
# Untest:
# 1. Slide bar for result set.
# 2.
