import argparse
from elasticsearch import Elasticsearch
from setup_index import verify_or_setup_index
from config import Config

#load the args & config
parser = argparse.ArgumentParser("Create an elasticsearch index for use with twitter monitor")
parser.add_argument("--configfile", "-c", default="config.json", required=False, help="Path to the config file to use.")
parser.add_argument("--indexname", "-i", required=True, help="Name of the index to create.")
args = parser.parse_args()

config = Config.load(args.configfile)
config.elasticsearch_index_name = args.indexname

#Verify or setup the elasticsearch index
es = Elasticsearch(hosts=[config.elasticsearch_host], 
                   verify_certs=config.elasticsearch_verify_certs,
                   timeout=config.elasticsearch_timeout_secs)

index_result = verify_or_setup_index(es, config)
print(index_result)
