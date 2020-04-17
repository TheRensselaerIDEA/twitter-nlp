"""
Tweepy StreamListener subclass responsible for forwarding incoming tweet data to
ElasticSearch.
"""
import tweepy
import logging
from config import Config
from elasticsearch.helpers import bulk


class TwitterMonitorStreamListener(tweepy.StreamListener):
    '''
    Tweets are known as “status updates”. So the Status class in tweepy has properties describing the tweet.
    https://developer.twitter.com/en/docs/tweets/data-dictionary/overview/tweet-object.html
    '''
    
    def __init__(self, es, config):
        super(TwitterMonitorStreamListener, self).__init__()
        
        self.es = es
        self.config = config
        self.batch = []
        self.batch_ids = set()
        self.received_data = False

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

        tweet_id = json_dict["id_str"]
        if tweet_id not in self.batch_ids:
            self.batch.append({"_op_type": "index", "_id": tweet_id, "_source": json_dict})
            self.batch_ids.add(tweet_id)
            logging.info("Queued tweet [id={0}]: \"{1}\"".format(tweet_id, json_dict["text"]))

        if retweet_json_dict is not None:
            retweet_id = retweet_json_dict["id_str"]
            if retweet_id not in self.batch_ids:
                self.batch.append({"_op_type": "index", "_id": retweet_id, "_source": retweet_json_dict})
                self.batch_ids.add(retweet_id)
                logging.info("Queued retweet [id={0}] for original tweet id: {1}".format(retweet_id, tweet_id))
    
        if len(self.batch) >= self.config.elasticsearch_batch_size:
            bulk(self.es, self.batch, index=self.config.elasticsearch_index_name, chunk_size=len(self.batch))
            self.batch.clear()
            self.batch_ids.clear()

        if not self.received_data:
            self.received_data = True

        return True
    
    def on_error(self, status_code):
        logging.error("Received error status code {0} from Twitter.".format(status_code))
        return True