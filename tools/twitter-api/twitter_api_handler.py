from scrolling import es, es_index, search
from elasticsearch import Elasticsearch
from error_handling import *
from elasticsearch.helpers import bulk
from random import randint
import json
import tweepy

class TwitterAPIHandler:
  def __init__(self):
    creds = json.load(open("creds.json"))
    self.creds = creds["twitter-creds"]
    
    self.consumer_key        = self.creds["consumer_key"]
    self.consumer_key_secret = self.creds["consumer_key_secret"]
    self.access_token        = self.creds["access_token"]
    self.access_token_secret = self.creds["access_token_secret"]
    self.auth = tweepy.OAuthHandler(self.consumer_key, self.consumer_key_secret)
    self.auth.set_access_token(self.access_token, self.access_token_secret)
    self.api = tweepy.API(self.auth, wait_on_rate_limit=True, wait_on_rate_limit_notify=True)

  def GetElasticSearchHitsWithScrolling(self, max_hits):
    """
    Uses Thomas Shweh's ElasticSearch scrolling algorithm to get max_hits number of Tweets from
    ElasticSearch
    """
    return search(max_hits=max_hits-1000)
      
  def GetFullText(self, apiResponse, index):
    """
    For testing to see if the tweet has an extended text
    """
    try:
      return apiResponse[index].full_text
    except:
      return -1
    

  def GetTweetsFromAPI(self, hits):
    """
    Gets the original tweet for each response-type hit from Twitter 
    and writes that original tweet to the exisiting data
    """
    output = list()
    responseTweetIds = [hit['_source']['in_reply_to_status_id'] for hit in hits]
    numUnavailable = 0
    for i in range(0, len(responseTweetIds), 100):
      apiResponse = self.api.statuses_lookup(responseTweetIds[i:i+100], tweet_mode="extended", map=True)
      responseIndex = 0
      for j in range(i, i+100):
        currHit = hits[j]
        currHit['_source']['in_reply_to_status'] = apiResponse[responseIndex]
          
        responseIndex += 1
        
        output.append(currHit)
        
    return output, numUnavailable
  
  def WriteDataToElasticSearch(self, hits):
    """
    Write the modified data back to the elasticsearch index
    """
    for i in range(0, len(hits), 100):
      process_batch = hits[i:i+100]
      del hits[i:i+100]
      bulk(self.es, process_batch, index=es_index, chunk_size=len(process_batch))
      
  
  def GetOriginalTweetsAndWriteToElasticSearch(self, num_tweets):
    """
    Gets num_tweets from ElasticSearch and then queries Twitter for the original tweet that the
    ElasticSearch Tweet was in response to. Once we get the original tweet, we write it back to 
    ElasticSearch with the key 'in_response_to_id'
    """
    hits = self.GetElasticSearchHitsWithScrolling(max_hits=num_tweets)
    tweets = self.GetTweetsFromAPI(hits)
    self.WriteDataToElasticSearch(hits)
    
    
if __name__ == "__main__":
  retriever = TwitterAPIHandler()
  """
  To run full functionality of the script, call:
  retriever.GetOriginalTweetsAndWriteToElasticSearch(self, num_tweets)
  """
