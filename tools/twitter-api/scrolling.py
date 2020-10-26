from elasticsearch import Elasticsearch, helpers
from random import randint
import json
config = json.load(open("config.json"))
 
es = Elasticsearch(
  [config["config"]["server"]],
  # turn on SSL
  use_ssl=True,
  # no verify SSL certificates
  verify_certs=False,
  # don't show warnings about ssl certs verification
  ssl_show_warn=False,
  timeout=30,
  max_retries=10,
  retry_on_timeout=True
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
 
es_index = 'coronavirus-data-all'
 
# helper methods to see which 
def printMappings():
  # print out searchable indexes in elasticsearch
  mapping = es.indices.get_mapping(es_index)
  with open('mapping.json', 'w') as f:
    f.write(json.dumps(mapping))
 
def validateTweets(tweets):
  for tweet in tweets:
    if 'in_reply_to_status_id_str' not in tweet['_source'] or not tweet['_source']['in_reply_to_status_id_str'].isnumeric():
      print('Non Reply Tweet found')
      print(tweet)
      return False
  return True
 
# method for continuously searching for all tweets
def search(max_hits=999999999):
  print('###########################')
  print('        Begin Search       ')
  print('###########################')
  response = []
 
  # perform a search for 2ms and get initial index
  page = es.search(index=es_index,
                       scroll='2m',
                       size=1000,
                       body=search_param)
  scroll_id = page['_scroll_id']
  scroll_size = page['hits']['total']['value']
  response.extend(page['hits']['hits'])
  print('%d Tweets Gathered' % (len(response)))
 
  # Start scrolling until we have all documents that match our query
  while (scroll_size > 0):
    if (len(response) >= max_hits):
      break
    page = es.scroll(scroll_id=scroll_id, scroll='2m')
    # Update the scroll ID
    scroll_id = page['_scroll_id']
    # Get the number of results that we returned in the last scroll
    validateTweets(page['hits']['hits'])
    scroll_size = len(page['hits']['hits'])
    response.extend(page['hits']['hits'])
    print('%d Tweets Gathered' % (len(response)))
  return response
 
if __name__ == '__main__':
  response = search(max_hits=1000)
  print(len(response))
 
# sentiment as a cluster
# chop up dataset by sentiment, negative, positive, neutral
# train a model on it
# what kind of accuracy we can get?
# custom attribute, to fill in quoted status
# output file as json line structure into elasticsearch, quoted status node, take whole json and output it
# create a new index for each usecase that we have
