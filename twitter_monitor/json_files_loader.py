"""
Script for populating an Elasticsearch index with tweets from JSON files.
"""
import argparse
import logging
import glob
import json
import os
from elasticsearch import Elasticsearch
from elasticsearch.helpers import bulk
from setup_index import verify_or_setup_index
from config import Config

#load the args & config
parser = argparse.ArgumentParser("Run the json file dataset loader")
parser.add_argument("--datasetglob", "-d", required=True, help="glob pattern specifying the jsonl file(s). Ex: './data/*.jsonl'")
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

#read and process the json file(s)
total_succeeded = 0
filenames = glob.glob(args.datasetglob)
num_files = len(filenames)
es_batch = []
for i, filename in enumerate(filenames):
    try:
        print()
        print("Loading {0}...".format(filename))
        print()
        filebasename = os.path.basename(filename)
        with open(filename, 'r') as f:
            json_dict = json.load(f)
        es_batch.append({"_op_type": "index", "_id": json_dict["id_str"], "_source": json_dict})

        #push to elasticsearch
        while len(es_batch) >= config.elasticsearch_batch_size or (i == num_files-1 and len(es_batch) > 0):
            process_batch = es_batch[:config.elasticsearch_batch_size]
            del es_batch[:config.elasticsearch_batch_size]
            bulk(es, process_batch, index=config.elasticsearch_index_name, chunk_size=len(process_batch))
            total_succeeded += len(process_batch)
            print("Succeeded (total): {0}".format(total_succeeded))
    except Exception as ex:
        logging.exception("Exception occurred while attempting to load {0}.".format(filename))
        print("Exception occurred while attempting to load {0}. See log for details.".format(filename))

print()
print ("Done!")