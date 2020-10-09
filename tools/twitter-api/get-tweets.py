from elasticsearch import Elasticsearch
from random import randint
import json
import tweepy

creds = json.load(open("creds.json"))
creds = creds["twitter-creds"]

consumer_key        = creds["consumer_key"]
consumer_key_secret = creds["consumer_key_secret"]
access_token        = creds["access_token"]
access_token_secret = creds["access_token_secret"]

auth = tweepy.OAuthHandler(consumer_key, consumer_key_secret)
auth.set_access_token(access_token, access_token_secret)
api = tweepy.API(auth)

def GetElasticSearchHits(): 
  es = Elasticsearch(
    ['lp01.idea.rpi.edu:443/elasticsearch'],
    # turn on SSL
    use_ssl=True,
    # no verify SSL certificates
    verify_certs=False,
    # don't show warnings about ssl certs verification
    ssl_show_warn=False
  )
   
  # create a Python dictionary for the search query:
  search_param = {
    "_source": True,
    "query": {
      "constant_score" : {
           "filter" : {
              "exists" : {
                 "field" : "in_reply_to_status_id_str"
              }
           }
      }
    }
  }
   
  # print out searchable indexes in elasticsearch
  mapping = es.indices.get_mapping('coronavirus-data-masks')
  with open('mapping.json', 'w') as f:
    f.write(json.dumps(mapping))
   
  # get a response from the cluster and write a random tweet
  response = es.search(index="coronavirus-data-masks", body=search_param)
  """
  with open('tweet.json', 'w') as f:
    length = len(response['hits']['hits'])
    index = randint(0, length - 1)
    f.write(json.dumps(response['hits']['hits'][index]))
    f.write(json.dumps(response))
  """
   
  # verify that tweets have been filtered
  print('Tweets Found:', len(response['hits']['hits']))
  for tweet in response['hits']['hits']:
    if tweet['_source']['in_reply_to_status_id_str'] is None:
      print('Non reply tweet found')
  
  return response['hits']['hits']
    
    

def GetTweetsFromAPI(hits):
  output = list()
  for hit in hits:

    pair = dict()
    reply_to_id = (hit['_source']['in_reply_to_status_id'])
    """
    Get the response tweet from elastic search
    """
    try:
      pair["response"] = hit['_source']['extended_tweet']['full_text']
    except:
      pair["response"] = hit['_source']['text']
    """
    Get the original tweet from twitter
    """  
    try:
      api_response = api.get_status(reply_to_id, tweet_mode="extended")
      pair["tweet"] = api_response.full_text
    except:
      api_response = api.get_status(reply_to_id)
      pair["tweet"] = api_reponse.text
    
    output.append(pair)
    
  return output
    
if __name__ == "__main__":
  hits = GetElasticSearchHits()
  pairs = GetTweetsFromAPI(hits)
  print(pairs)
