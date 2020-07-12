"""
Script for populating an Elasticsearch index with tweets from a jsonl dataset,
including the original jsonl object along with each tweet.
"""
import argparse
import tweepy
import logging
import glob
import json
import os
from elasticsearch import Elasticsearch
from elasticsearch.helpers import bulk
from setup_index import verify_or_setup_index
from config import Config

#load the args & config
parser = argparse.ArgumentParser("Run the jsonl dataset loader")
parser.add_argument("--datasetglob", "-d", required=True, help="glob pattern specifying the jsonl file(s). Ex: './data/*.jsonl'")
parser.add_argument("--tweetidfieldname", "-t", default="id", required=False, help="Name of json field containing the tweet id.")
parser.add_argument("--configfile", "-c", default="config.json", required=False, help="Path to the config file to use.")
parser.add_argument("--logfile", "-l", default="jdllog.txt", required=False, help="Path to the log file to write to.")
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

#read and process the jsonl file(s)
total_attempted = 0
total_succeeded = 0
filenames = glob.glob(args.datasetglob)
for filename in filenames:
    try:
        print()
        print("Loading {0}...".format(filename))
        print()
        filebasename = os.path.basename(filename)
        file_attempted = 0
        file_succeeded = 0
        tw_batch = {}
        es_batch = []
        with open(filename, 'r') as f:
            num_lines = sum(1 for line in f)
            f.seek(0)
            for i, line in enumerate(f):
                #read the line and queue the tweet for lookup from twitter
                if (line.strip() != ""):
                    line_obj = json.loads(line)
                    tw_batch[line_obj[args.tweetidfieldname]] = line_obj
                
                #do the lookup and queue the results for push to elasticsearch
                if len(tw_batch) == 100 or (i == num_lines-1 and len(tw_batch) > 0):
                    tw_batch_ids = [k for k in tw_batch.keys()]
                    tw_batch_statuses = api.statuses_lookup(tw_batch_ids, tweet_mode="extended")
                    for status in tw_batch_statuses:
                        json_dict = status._json
                        json_dict["dataset_entry"] = tw_batch[json_dict["id_str"]]
                        json_dict["dataset_file"] = filebasename
                        es_batch.append({"_op_type": "index", "_id": json_dict["id_str"], "_source": json_dict})
                    file_attempted += len(tw_batch)
                    total_attempted += len(tw_batch)
                    tw_batch.clear()

                #push to elasticsearch
                while len(es_batch) >= config.elasticsearch_batch_size or (i == num_lines-1 and len(es_batch) > 0):
                    process_batch = es_batch[:config.elasticsearch_batch_size]
                    del es_batch[:config.elasticsearch_batch_size]
                    bulk(es, process_batch, index=config.elasticsearch_index_name, chunk_size=len(process_batch))
                    file_succeeded += len(process_batch)
                    total_succeeded += len(process_batch)
                    print("Attempted (file): {0}; Succeeded (file): {1}; Attempted (total): {2}; Succeeded (total): {3}"
                        .format(file_attempted, file_succeeded, total_attempted, total_succeeded))
    except Exception as ex:
        logging.exception("Exception occurred while attempting to load {0}.".format(filename))
        print("Exception occurred while attempting to load {0}. See log for details.".format(filename))

print()
print ("Done!")