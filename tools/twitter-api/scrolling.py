from elasticsearch import Elasticsearch, helpers
from random import randint
import json
config = json.load(open("config.json"))

# configure elasticsearch client
es_config = config["config"]["elasticsearch"]
client_config = config["config"]["client"]
es_url = f"{es_config['es_host']}:{es_config['es_port']}/{es_config['es_path']}"
es = Elasticsearch(
  [es_url],
  # turn on SSL
  use_ssl=client_config["use_ssl"],
  # no verify SSL certificates
  verify_certs=client_config["verify_certs"],
  # don't show warnings about ssl certs verification
  ssl_show_warn=client_config["ssl_show_warn"],
  timeout=client_config["timeout"],
  max_retries=client_config["max_retries"],
  retry_on_timeout=client_config["retry_on_timeout"]
)
 
# create a Python dictionary for the search query:
search_param = {
  "_source": True,
  "query": {
    "bool": {
      "filter": [
        {
          "exists": {
            "field": "in_reply_to_status_id_str"
          }
        },
        {
          "simple_query_string": {
            "fields": [
              "in_reply_to_screen_name"
            ],
            "query": "ESCAIDE ECDCPHT ecdc_tb ECDC_VPD ECDC_HIVAIDS ecdc_flu ECDC_Outbreaks ecdc_eu WHO cdcgov cdcdirector CDC_eHealth CDCespanol BRFSS CDCasthma CDC_DASH CDCDiabetes cdc_drh CDCEnvironment CDC_Cancer CDC_EIDjournal CDC_EPHTracking CDC_Genomics CDC_HIVAIDS CDCMicrobeNet CDC_NCBDDD CDC_NCEZID CDC_TB CDC_AMD CDCChronic CDCEmergency CDCFlu CDCGlobal CDCGreenHealthy CDCHaiti CDCHeart_Stroke US_CDCIndia CDChep CDCInjury CDCKenya CDCMakeHealthEZ CDCMMWR CDCNPIN CDCObesity cdcpcd CDCRwanda CDCsouthafrica CDCSTD CDCTobaccofree CDCTravel CPSTF DrDeanCDC DrKhabbazCDC DrMartinCDC DrMerminCDC DrNancyM_CDC DrReddCDC InjectionSafety MillionHeartsUS NCHStats niosh NIOSHMining NIOSH_MVSafety NIOSH_NPPTL NIOSH_TWH nioshbreathe NIOSHConstruct NIOSHespanol NIOSHFACE nioshfishing nioshnoise NIOSHoilandgas WTCHealthPrgm"
          }
        }
      ]
    }
  }
}

# helper to check if filtering worked
def validateTweets(tweets):
  for tweet in tweets:
    if tweet['_source']['in_reply_to_status_id_str'] is None:
      print("Tweet reply to status id is None")
      print(tweet)
      return False
    if 'in_reply_to_status_id_str' not in tweet['_source'] or not tweet['_source']['in_reply_to_status_id_str'].isnumeric():
      print('Non Reply Tweet found')
      print(tweet)
      return False
  return True
 
# method for continuously searching for all tweets
def search(es_index, max_hits=None):
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
  ids = [scroll_id]
  scroll_size = page['hits']['total']['value']
  response.extend(page['hits']['hits'])
  print('%d Tweets Gathered' % (len(response)))
 
  # Start scrolling until we have all documents that match our query
  while (scroll_size > 0):
    if len(response) >= max_hits:
      return response
    if (max_hits != None and len(response) >= max_hits):
      break
    page = es.scroll(scroll_id=scroll_id, scroll='2m')
    # Update the scroll ID
    scroll_id = page['_scroll_id']
    ids.append(scroll_id)
    # Get the number of results that we returned in the last scroll
    validateTweets(page['hits']['hits'])
    scroll_size = len(page['hits']['hits'])
    response.extend(page['hits']['hits'])
    print('%d Tweets Gathered' % (len(response)))
  
  es.clear_scroll(body=None, scroll_id=",".join(ids))
  return response
 
if __name__ == '__main__':
  response = search("coronavirus-data-all", max_hits=1000)
  print(len(response))
 
