import re
import math
import numpy as np
import torch
import html

def get_query():
    query = {
    "_source": [
        "text",
        "full_text",
        "extended_tweet.full_text",
        "quoted_status.text",
        "quoted_status.full_text",
        "quoted_status.extended_tweet.full_text"
    ],
    "query": {
        "bool": {
        "filter": [
            {
              "bool": {
                "should": [
                  {
                    "bool": {
                      "must_not": {
                        "exists": {
                          "field": "sentiment.vader.primary"
                        }
                      }
                    }
                  },
                  {
                    "bool": {
                      "must_not": {
                        "exists": {
                          "field": "sentiment.roberta.primary"
                        }
                      }
                    }
                  }
                ]
              }
            },
            {
            "bool": {
                "must_not": {
                "exists": {
                    "field": "retweeted_status.id"
                  }
                }
              }
            }
          ]
        }
      }
    }
    return query

def get_tweet_text(hit):
    text = (hit["extended_tweet"]["full_text"] if "extended_tweet" in hit 
            else hit["full_text"] if "full_text" in hit 
            else hit["text"])
    quoted_text = None
    if "quoted_status" in hit:
        quoted_status = hit["quoted_status"]
        quoted_text = (quoted_status["extended_tweet"]["full_text"] if "extended_tweet" in quoted_status 
                      else quoted_status["full_text"] if "full_text" in quoted_status 
                      else quoted_status["text"])

    return text, quoted_text

def clean_text_for_vader(text):
    text = html.unescape(text)
    text = re.sub("’", "'", text)
    text = re.sub(r"[\s]+", " ", text)
    text = re.sub(r"http\S+", "", text)
    text = re.sub(r" +", " ", text)
    text = text.strip()
    return text

def get_sentiment(responses, batch_size, max_length, sentiment_model, sentiment_tokenizer, device):
    n_batches = math.ceil(len(responses) / batch_size)
    batches = [None] * n_batches
    for i in range(n_batches):
        start = i * batch_size
        end = start + batch_size   
        batch_inputs = sentiment_tokenizer(responses[start:end], 
                                            padding=True, 
                                            truncation=True, 
                                            return_tensors="pt", 
                                            max_length=max_length)
        batch_inputs = batch_inputs.to(device)
        
        class_weights = torch.tensor([-1., 0., 1.]).to(device)
        
        with torch.no_grad():
            logits = sentiment_model(**batch_inputs).logits
            probs = torch.nn.functional.softmax(logits, dim=-1)
            #Convert polarity classes (negative, positive) to score in (-1, 1)
            polarity_scores = torch.matmul(probs, class_weights)
            
        batches[i] = polarity_scores.to("cpu").numpy()
    
    scores = np.concatenate(batches, axis=0)
        
    return scores