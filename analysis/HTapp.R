#
# This is a Shiny web application. You can run the application by clicking
# the 'Run App' button above.
#
# Find out more about building applications with Shiny here:
#
#    http://shiny.rstudio.com/
#

library(shiny)
#Source and Package You need to upload
if (!require("knitr")) {
    install.packages("knitr")
    library(knitr)
}

if (!require("kableExtra")) {
    install.packages("kableExtra")
    library(kableExtra)
}

knitr::opts_chunk$set(echo = TRUE)
library(maps)
library(ggplot2)
source("Elasticsearch.R")
source("plot_tweet_sentiment_timeseries.R")

#Function 
find.State <- function(row){
    usrPL <- row$place.full_name
    abb <- state.abb 
    name <- state.name 
    for( itr in abb )
    {
        if( grepl(itr, usrPL, fixed=TRUE))
        {
            return(itr)
        }
    }
    for(idx in 1:length(abb))
    {
        itr = name[idx]
        if(grepl(itr,usrPL,fixed=TRUE)){
            return(abb[idx])
        }
    }
    return("USA")
}
find.State.Map <- function(row){
    usrPL <- row
    abb <- state.abb 
    name <- state.name 
    
    for(idx in 1:length(abb))
    {
        itr = name[idx]
        if(tolower(itr) == row ){
            return(abb[idx])
        }
    }
    return("USA")
}






#Plot Function 
plot = function(result){
    ggplot(result, aes(x = long, y = lat, group=group ,fill = mean_sentiment)) + 
        geom_polygon(name = "Sentiment Average",colour="black")+
        scale_fill_gradient2(name = "Sentiment Average", limits = c(-1,1), low = "red", mid = "white", high = "green", midpoint = 0)
}

# Define UI for application that draws a histogram
ui <- fluidPage(

    # Application title
    titlePanel("Test for APP"),

    # Sidebar with a slider input for number of bins 
    sidebarLayout(
        sidebarPanel(
            sliderInput("Time",
                        "Months:",
                        min = as.Date("2020-04-01"),max =as.Date("2020-08-01"),value=as.Date("2020-08-01"),timeFormat="%b %Y")
        ),

        # Show a plot of the generated distribution
        mainPanel(
           leafletOutput("mymap"),
           plotOutput("SummaryCount"),
           tableOutput("DetailTweets")
        )
    )
)

# Define server logic required to draw a histogram
server <- function(input, output) {

    output$SummaryCount <- renderPlot({
        
        fig1 <- ggplot(summary.tibble, aes(x = location, y = count, fill = mean_sentiment)) + 
            geom_bar(stat = "identity", color = "azure3") + 
            scale_fill_gradient2(name = "Sentiment Average", limits = c(-1,1), low = "red", mid = "white", high = "green", midpoint = 0) +
            ggtitle("Tweets by Location") + 
            ylab("Tweet Count") +
            theme(axis.title.x = element_blank() ,axis.text.x = element_text(angle = 90, vjust = 0.5, hjust=1)   )
        fig2 <- ggplot(summary.tibble, aes(x = location, y = divisiveness)) + 
            geom_bar(fill = "purple", stat = "identity") + 
            geom_hline(yintercept = 0, color = "red", linetype = "dashed") +
            ylab("Divisiveness") +
            xlab("Date") + 
            theme_grey(base_size = 9) + theme(axis.text.x=element_text(angle=90))
        fig3<- ggplot(summary.tibble, aes(x = location, y =  mean_sentiment, fill = mean_sentiment)) + 
            geom_bar(stat = "identity", color = "azure3") + 
            scale_fill_gradient2(name = "Sentiment Average", limits = c(-1,1), low = "red", mid = "white", high = "green", midpoint = 0) +
            ggtitle("Tweets senitment by Location") + 
            ylab("Tweet Count") +
            theme(axis.title.x = element_blank() ,axis.text.x = element_text(angle = 90, vjust = 0.5, hjust=1)   )
        ggarrange(fig1, fig2,fig3, nrow = 3, heights = c(1, 0.25,1))
    })
    
    output$mymap <- renderLeaflet({
        print("Get into RenderLeaflet")
        print(input$Time)
        rangestart <- "2020-03-01 00:00:00"
        rangeend <- paste(input$Time,"00:00:00")
        text_filter <- ""
        location_filter <- ""
        must_have_geo <- TRUE 
        semantic_phrase <- ""
        random_sample <- TRUE
        random_seed <- NA
        resultsize <- 10000
        min_results <- 1
        results <- do_search(indexname="coronavirus-data-masks",  #coronavirus-data-masks
                             rangestart=rangestart,
                             rangeend=rangeend,
                             text_filter=text_filter,
                             location_filter=location_filter,
                             semantic_phrase=semantic_phrase,
                             must_have_geo=must_have_geo,
                             random_sample=random_sample,
                             random_seed=random_seed,
                             resultsize=resultsize,
                             resultfields='"created_at", "user.screen_name", "user.location","normalized_state", "place.full_name", "place.country", "text", "full_text", "extended_tweet.full_text", "sentiment.vader.primary"',
                             elasticsearch_host="lp01.idea.rpi.edu",
                             elasticsearch_path="elasticsearch",
                             elasticsearch_port=443,
                             elasticsearch_schema="https")
        
        required_fields <- c("created_at", "user_screen_name", "user_location","normalized_state", "place.full_name", "place.country", "full_text", "sentiment.vader.primary")
        validate_results(results$df, min_results, required_fields)
        results.df <- results$df
        colnames(results.df)[colnames(results.df) == "sentiment.vader.primary"] <- "sentiment"
        results.df$vector_type <- "tweet"
        tweets.df <- results.df[results.df$place.country=="United States",]
        tweets.df$created_at <- as.POSIXct(strptime(tweets.df$created_at, format="%a %b %d %H:%M:%S +0000 %Y", tz="UTC"))
        tweets.df$week <- epiweek(tweets.df$created_at)  # find CDC epidemiological week
        tweets.df$date <- date(tweets.df$created_at)
        tweet.tibble <- tibble(sentiment = tweets.df$sentiment, week = tweets.df$week, date = tweets.df$date, datetime = tweets.df$created_at, location = apply(tweets.df,1,find.State)  )
        
        summary.tibble <- tweet.tibble %>% group_by(location) %>% summarize(mean_sentiment = mean(sentiment), sd_sentiment = sd(sentiment), count = length(datetime), divisiveness = divisiveness_score(sentiment))
        summary.tibble$divisiveness[is.na(summary.tibble$divisiveness)] <- 0
        summary.tibble <- summary.tibble %>% ungroup()
        summary.tibble <- summary.tibble[summary.tibble$location != "USA",]
        state_data <- ggplot2::map_data('state')
        state_data$loc <- sapply(state_data$region,find.State.Map)
        result = merge(state_data,summary.tibble,by.x= "loc",by.y="location")
        
        print("Got the results")
        
        colors <- c("#253494","#4575B4", "#74ADD1","#ABD9E9","#f7f7f7","#FDAE61","#F46D43", "#D73027", "#BD0026")
        
        states_merged_sb <- geo_join(states, summary.tibble, "STUSPS", "location")
        pal <- colorNumeric(rev(colors), domain=states_merged_sb$mean_sentiment)
        states_merged_sb <- subset(states_merged_sb, !is.na(mean_sentiment))
        popup_sb <- paste0("Mean Sentiment: ", as.character(states_merged_sb$mean_sentiment))
        
        leaflet() %>%
            setView(-98.483330, 38.712046, zoom = 4) %>% 
            addPolygons(data = states_merged_sb , 
                        fillColor = ~pal(states_merged_sb$mean_sentiment), 
                        fillOpacity = 0.7, 
                        weight = 0.2, 
                        smoothFactor = 0.2, 
                        popup = ~popup_sb,
                        dashArray = "3",
                        highlight = highlightOptions(weight=5,color="#666",dashArray="",fillOpacity = 0.7, bringToFront = TRUE)) %>%
            addLegend(pal = pal, 
                      values = states_merged_sb$mean_sentiment, 
                      position = "bottomright", 
                      title = "Mean_sentiment")
    })
    
    output$DetailTweets <- function(){
        library(dplyr)
        tmp.df <- tweets.df %>% group_by(normalized_state)%>% sample_n(2,replace = TRUE)
        
        kable(tmp.df[,c("created_at","text","normalized_state","sentiment")]) %>% kable_styling()
    }
}

# Run the application 
shinyApp(ui = ui, server = server)
