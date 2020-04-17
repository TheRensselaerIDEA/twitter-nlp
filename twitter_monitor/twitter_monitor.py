"""
Script for running the twitter monitor listener/processor
"""
import argparse
import time
import tweepy
import logging
from elasticsearch import Elasticsearch
from setup_index import verify_or_setup_index
from config import Config
from tm_stream_listener import TwitterMonitorStreamListener

#load the args & config
parser = argparse.ArgumentParser("Run the twitter monitor listener/processor")
parser.add_argument("--configfile", "-c", default="config.json", required=False, help="Path to the config file to use.")
parser.add_argument("--logfile", "-l", default="tmlog.txt", required=False, help="Path to the log file to write to.")
args = parser.parse_args()

config = Config.load(args.configfile)

#Configure logging
logging.basicConfig(filename=args.logfile, 
                    format="[%(asctime)s - %(levelname)s]: %(message)s", 
                    level=logging.getLevelName(config.log_level))
print("Logging level set to {0}...".format(config.log_level))
print()

#Verify or setup the elasticsearch index
es = Elasticsearch(hosts=[config.elasticsearch_host], 
                   verify_certs=config.elasticsearch_verify_certs,
                   timeout=config.elasticsearch_timeout_secs)

index_result = verify_or_setup_index(es, config)
logging.info(index_result)
print(index_result)
print()

#load the credentials and initialize tweepy
auth  = tweepy.OAuthHandler(config.api_key, config.api_secret_key)
auth.set_access_token(config.access_token, config.access_token_secret)
api = tweepy.API(auth, wait_on_rate_limit=True, wait_on_rate_limit_notify=True)

#listen to the stream API

restart_attempts = 0
while True:
    try:
        streamListener = TwitterMonitorStreamListener(es, config)
        stream = tweepy.Stream(auth=api.auth, listener=streamListener)
        print("Listening for tweets...")
        print()
        logging.info("Starting listener...")
        stream.filter(languages=config.filter_languages, track=config.filter_keywords)
    except Exception as ex:
        logging.exception("Exception occurred while listening.")
        if streamListener.received_data:
            restart_attempts = 0
    
    restart_attempts += 1
    if config.restart_attempts > -1 and restart_attempts > config.restart_attempts:
        logging.critical("Restart attempt limit reached. Shutting down...")
        break
    
    logging.warning("Restarting after {0} seconds (attempt {1})...".format(config.restart_wait_secs, restart_attempts))
    time.sleep(config.restart_wait_secs)

