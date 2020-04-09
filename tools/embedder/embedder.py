import argparse
import numpy as np
import pandas as pd
import math
import embedder_helpers
from elasticsearch import Elasticsearch
from elasticsearch_dsl import Search
from clean_text import clean_text

from config import Config

parser = argparse.ArgumentParser("Run the dataset builder")
parser.add_argument("--configfile", "-c", default="config.json", required=False, help="Path to the config file to use.")
parser.add_argument("--modeltype", "-m", default="Word2Vec", required=False, help="Type of model to use for vectorization.")
parser.add_argument("--modelfile", "-f", default="400features_10minwords_5context", required=False, help="Filename of model.")
parser.add_argument("--batchsize", "-b", default=1024, required=False, type=int, help="Number of tweets to embed in one shot (when using Tensorflow model.")

print()
print("Running with arguments:")
print(args)
print()

config = Config.load(args.configfile)

es = Elasticsearch(hosts=[config.elasticsearch_host], 
                   verify_certs=config.elasticsearch_verify_certs)

while True:
    s = Search(using=es, index=config.elasticsearch_index_name)
    s = s.params(size=args.batchsize)
    s.update_from_dict(embedder_helpers.get_query())
    
    hits = s.execute()
    updates = []
    for hit in hits:
        