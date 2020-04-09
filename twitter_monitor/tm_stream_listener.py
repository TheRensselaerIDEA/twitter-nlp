"""
Tweepy StreamListener subclass responsible for forwarding incoming tweet data to
ElasticSearch.
"""
import tweepy
import logging
from config import Config
from elasticsearch import Elasticsearch


class TwitterMonitorStreamListener(tweepy.StreamListener):
    '''
    Tweets are known as “status updates”. So the Status class in tweepy has properties describing the tweet.
    https://developer.twitter.com/en/docs/tweets/data-dictionary/overview/tweet-object.html
    '''
    
    def __init__(self, config):
        super(TwitterMonitorStreamListener, self).__init__()
        
        self.config = config
        self.received_data = False
            
        self.es = Elasticsearch(hosts=[self.config.elasticsearch_host], 
                                verify_certs=self.config.elasticsearch_verify_certs)

    def on_status(self, status):
        '''
        Extract info from tweets
        '''
        json_dict = status._json
        retweet_json_dict = None

        if "retweeted_status" in json_dict:
            logging.info("Extracting retweet...")
            #pull retweet user and basic metadata into its own dict (this will be persisted to ES separately)
            retweet_json_dict = {
                "created_at": json_dict["created_at"],
                "id": json_dict["id"],
                "id_str": json_dict["id_str"],
                "user": json_dict["user"],
                "coordinates": json_dict["coordinates"],
                "place": json_dict["place"],
                "timestamp_ms": json_dict["timestamp_ms"],
                "retweeted_status": {
                    "id": json_dict["retweeted_status"]["id"],
                    "id_str": json_dict["retweeted_status"]["id_str"]
                }
            }
            #pull original out into its own dict (this will be persisted to ES separately)
            json_dict = json_dict["retweeted_status"]


        self.es.index(index=self.config.elasticsearch_index_name, doc_type="_doc", body=json_dict, id=json_dict["id_str"])
        logging.info("Ingested tweet [id={0}]: \"{1}\"".format(json_dict["id_str"], json_dict["text"]))

        if retweet_json_dict is not None:
            self.es.index(index=self.config.elasticsearch_index_name, doc_type="_doc", body=retweet_json_dict, id=retweet_json_dict["id_str"])
            logging.info("Ingested retweet [id={0}] for original tweet id: {1}".format(
                retweet_json_dict["id_str"], retweet_json_dict["retweeted_status"]["id_str"]))
    
        if not self.received_data:
            self.received_data = True

        return True
    
    def on_error(self, status_code):
        logging.error("Received error status code {0} from Twitter.".format(status_code))
        return True