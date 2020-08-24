if (!require("httr")) {
  install.packages("httr")
  library(httr)
}

summarize <- function(text,
                      max_len=60, 
                      num_beams=4,
                      temperature=1.0,
                      model=NULL,
                      summarizer_url="http://localhost:8080/batchsummarize") {
  
  if (is.character(text) && length(text) == 1) {
    text = list(text)
  }
  
  body <- list(max_len = max_len, 
            num_beams = num_beams,
            temperature = temperature,
            text = text)
  if (!is.null(model)) {
    body$model <- model
  }
  
  res <- POST(url=summarizer_url, encode="json", body=body)
  
  res.text <- unlist(content(res))
  return(res.text)
}

