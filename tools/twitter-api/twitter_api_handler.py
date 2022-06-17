from scrolling import es, search, config_es_index
from elasticsearch.helpers import bulk
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
    self.es = es

  def GetElasticSearchHitsWithScrolling(self, es_index, max_hits):
    """
    Uses Thomas Shweh's ElasticSearch scrolling algorithm to get max_hits number of Tweets from
    ElasticSearch
    """
    if max_hits != None:
      max_hits = max_hits - 1000
    return search(es_index=es_index, max_hits=max_hits)
      
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
    # """
    output = []
    numUnavailable = 0
    for i in range(0, len(hits), 100):
      responseTweetIds = list(set([hit["_source"]["in_reply_to_status_id_str"] for hit in hits[i:i+100]]))
      apiResponse = self.api.statuses_lookup(responseTweetIds, tweet_mode="extended", map_=True)
      apiResponseDict = {tweet._json["id_str"]: tweet._json for tweet in apiResponse if "id_str" in tweet._json}
      
      numUnavailable += (len(responseTweetIds) - len(apiResponseDict))
      for j in range(i, min(i+100, len(hits))):
          currHit = hits[j]
          inReplyToId = currHit["_source"]["in_reply_to_status_id_str"]
          if inReplyToId in apiResponseDict:
              currHit["_source"]["in_reply_to_status"] = apiResponseDict[inReplyToId]
              output.append(currHit) 

    return output, numUnavailable
      
  
  def WriteDataToElasticSearch(self, hits, es_index):
    """
    Write the modified data back to the elasticsearch index
    """
    if es_index is None:
        es_index = config_es_index
    
    updates = list()
    for hit in hits:
      irs = hit["_source"]["in_reply_to_status"]
      keys = irs.keys()
      if not (("id_str"not in keys) or ("created_at" not in keys) or ("user" not in keys) or ("full_text" not in keys)):
        action = {
            "_op_type": "update",
            "_id": hit["_id"],
            "doc": {
                "in_reply_to_status": {
                "id_str": irs["id_str"], 
                "created_at": irs["created_at"], 
                "screen_name": irs["user"]["screen_name"], 
                "full_text": irs["full_text"]
                }
            }
        }
    
        updates.append(action)
      else:
        print("bad data point")

    #Issue the bulk update request
    bulk(self.es, updates, index=es_index)
      
  
  def GetOriginalTweetsAndWriteToElasticSearch(self, es_index, num_tweets):
    """
    Gets num_tweets from ElasticSearch and then queries Twitter for the original tweet that the
    ElasticSearch Tweet was in response to. Once we get the original tweet, we write it back to 
    ElasticSearch with the key 'in_response_to_id'
    """
    hits = self.GetElasticSearchHitsWithScrolling(es_index, max_hits=num_tweets)
    tweets = self.GetTweetsFromAPI(hits)
    self.WriteDataToElasticSearch(tweets[0], es_index)
    
    
if __name__ == "__main__":
  retriever = TwitterAPIHandler()
  retriever.GetOriginalTweetsAndWriteToElasticSearch(None, None)
  """
  To run full functionality of the script, call:
  retriever.GetOriginalTweetsAndWriteToElasticSearch(self,es_index, num_tweets)
  """
