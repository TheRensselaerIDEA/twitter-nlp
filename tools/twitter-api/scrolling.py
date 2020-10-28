from elasticsearch import Elasticsearch, helpers
from random import randint
import json
config = json.load(open("config.json"))

# configure elasticsearch client
es_config = config["config"]["elasticsearch"]
es_url = f"{es_config['es_host']}/{es_config['es_path']}:{es_config['es_port']}"
es = Elasticsearch(
  [es_url],
  # turn on SSL
  use_ssl=config["client"]["use_ssl"],
  # no verify SSL certificates
  verify_certs=config["client"]["verify_certs"],
  # don't show warnings about ssl certs verification
  ssl_show_warn=config["client"]["ssl_show_warn"],
  timeout=config["client"]["timeout"],
  max_retries=config["client"]["max_retries"],
  retry_on_timeout=config["client"]["retry_on_timeout"]
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
 
es_index = config["config"]["es_index"]

# helper to check if filtering worked
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
 
