import argparse
import numpy as np
import pandas as pd
import math
import dataset_helpers
from elasticsearch import Elasticsearch
from elasticsearch_dsl import Search
from clean_text import clean_text

from config import Config

#load the args & config
parser = argparse.ArgumentParser("Run the dataset builder")
parser.add_argument("--configfile", "-c", default="config.json", required=False, help="Path to the config file to use.")
parser.add_argument("--modeltype", "-m", default="Word2Vec", required=False, help="Type of model to use for vectorization.")
parser.add_argument("--modelfile", "-f", default="400features_10minwords_5context", required=False, help="Filename of model.")
parser.add_argument("--batchsize", "-b", default=1024, required=False, type=int, help="Number of tweets to embed in one shot (when using Tensorflow model.")
parser.add_argument("--numresults", "-n", default=-1, required=False, type=int, help="Number of tweets to query and embed. -1 to query all tweets.")
parser.add_argument("--randomsample", "-r", action="store_true", required=False, help="Sample random results in the query.")
args = parser.parse_args()

print()
print("Running with arguments:")
print(args)
print()

config = Config.load(args.configfile)

#query the data
print("Querying data...")
print()
es = Elasticsearch(hosts=[config.elasticsearch_host], 
                   verify_certs=config.elasticsearch_verify_certs)

#------Uncomment to troubleshoot ES query issues-------------------
#import logging
#logging.getLogger("elasticsearch.trace").setLevel(logging.getLevelName("INFO"))
#logging.getLogger("elasticsearch.trace").propagate = True
#logging.getLogger("elasticsearch.trace").addHandler(logging.StreamHandler())
#------------------------------------------------------------------

s = Search(using=es, index=config.elasticsearch_index_name)
query = {
  "query": {
    "bool": {
      "must_not": {
        "exists": {
          "field": "retweeted_status.id"
        }
      }
    }
  }
}
if args.randomsample:
  s = s.params(preserve_order=True)
  query = {"query": {
    "function_score": {
      "query": query["query"],
      "random_score": {},
      "boost_mode": "replace"
    }
  }}

s.update_from_dict(query)

tweets = []
for i, hit in enumerate(s.scan()):
    text = dataset_helpers.get_tweet_text(hit)
    location, location_type = dataset_helpers.get_tweet_location(hit)
    username, verified = dataset_helpers.get_tweet_user(hit)
    tweets.append((text, username, verified, location, location_type))
    if args.numresults != -1 and i+1 == args.numresults:
        break

num_tweets = len(tweets)
print("{0} tweets found.".format(num_tweets))
print()

#clean the text
print ("Cleaning text...")
print()
if args.modeltype == "Word2Vec":
    tweets = [(clean_text(t, normalize_case=True, blacklist_regex="non_alpha_numeric"), 
               u, v, clean_text(l), p) for t, u, v, l, p in tweets]
elif args.modeltype == "TFHub":
    tweets = [(clean_text(t), u, v, clean_text(l), p) for t, u, v, l, p in tweets]
else:
    raise "Unknown model type."
    
#filter out empty tweets and replace empty locations
tweets = [t for t in tweets if t[0] != ""]
tweets = [(t, u, v, l if l != "" else "[No location available]", p) for t, u, v, l, p in tweets]
empty_tweets = num_tweets-len(tweets)
if empty_tweets > 0:
    print("Removed {0} empty tweet(s).".format(empty_tweets))
    print("Continuing with {0} tweets...".format(len(tweets)))
    print()  

#get the vectors
print ("Getting tweet vectors using {0} model loaded from {1}...".format(args.modeltype, args.modelfile))
print()
if args.modeltype == "Word2Vec":
    from gensim.models import Word2Vec
    model = Word2Vec.load(args.modelfile)
    tweets_words = [[word if word in model.wv.vocab else "unk" for word in t[0].split()] for t in tweets]

    tweets_word_vecs = [np.array([model.wv.word_vec(w) for w in words]) for words in tweets_words]
    tweet_vecs = np.array([np.mean(tweet_word_vecs, axis=0) for tweet_word_vecs in tweets_word_vecs])
elif args.modeltype == "TFHub":
    import tensorflow_hub as hub
    model = hub.load(args.modelfile)
    
    batches = math.ceil(len(tweets) / args.batchsize)
    for i in range(batches): 
        print ("Batch {0} of {1}...".format(i+1, batches))
        start = i * args.batchsize
        end = start + args.batchsize
        batch_tweet_vecs = np.array(model([t[0] for t in tweets[start:end]]))
        if i == 0:
            tweet_vecs = batch_tweet_vecs
        else:
            tweet_vecs = np.concatenate((tweet_vecs, batch_tweet_vecs))
else:
    raise "Unknown model type."

#export the dataset
print()
print ("Writing output file...")
print()
df = pd.DataFrame(tweet_vecs)
df.insert(0, "tweets_location_type", [t[4] for t in tweets], True)
df.insert(0, "tweets_location", [t[3] for t in tweets], True)
df.insert(0, "tweets_user_verified", [t[2] for t in tweets], True)
df.insert(0, "tweets_user_name", [t[1] for t in tweets], True)
df.insert(0, "tweets_text", [t[0] for t in tweets], True)
df.to_csv("tweet_vectors.csv", header=True, index=False)

print ("Done!")