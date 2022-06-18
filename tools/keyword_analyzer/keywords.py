import argparse
import logging
import re
from nltk.corpus import stopwords
from elasticsearch import Elasticsearch
from elasticsearch_dsl import Search

from config import Config

def count_word_freq(text, frequencies, stopwords):
    text = clean_text(text)
    text = text.lower()
    text_words = text.split()
    for word in text_words:
        if word not in stopwords:
            if word in frequencies:
                frequencies[word] += 1
            else:
                frequencies[word] = 1

def get_query():
    query = {
    "_source": [
        "text",
        "full_text",
        "extended_tweet.full_text",
        "quoted_status.text",
        "quoted_status.full_text",
        "quoted_status.extended_tweet.full_text"
    ],
    "query": {
        "bool": {
        "filter": [
            {
            "bool": {
                "must_not": {
                "exists": {
                    "field": "retweeted_status.id"
                  }
                }
              }
            }
          ]
        }
      }
    }
    return query

def get_tweet_text(hit):
    text = (hit["extended_tweet"]["full_text"] if "extended_tweet" in hit 
            else hit["full_text"] if "full_text" in hit 
            else hit["text"])
    quoted_text = None
    if "quoted_status" in hit:
        quoted_status = hit["quoted_status"]
        quoted_text = (quoted_status["extended_tweet"]["full_text"] if "extended_tweet" in quoted_status 
                      else quoted_status["full_text"] if "full_text" in quoted_status 
                      else quoted_status["text"])

    return text, quoted_text

def clean_text(text):
  text = re.sub(r"[\s]+", " ", text)
  text = re.sub(r"http\S+", "", text)
  text = re.sub(r"[^a-zA-Z0-9 ']+", "", text)
  text = re.sub(r" +", " ", text)
  text = text.strip()
  return text

####################################################################################
parser = argparse.ArgumentParser("Run the keyword analyzer")
parser.add_argument("--configfile", "-c", default="config.json", required=False, help="Path to the config file to use.")
parser.add_argument("--logfile", "-l", default="keywordslog.txt", required=False, help="Path to the log file to write to.")
parser.add_argument("--maxcount", "-m", default=100000, type=int, required=False, help="Maximum number of tweets to retrieve.")
args = parser.parse_args()

print()
print("Running with arguments:")
print(args)
print()

config = Config.load(args.configfile)

#Configure logging
logging.basicConfig(filename=args.logfile, 
                    format="[%(asctime)s - %(levelname)s]: %(message)s", 
                    level=logging.getLevelName(config.log_level))
print("Logging level set to {0}...".format(config.log_level))
print()

es = Elasticsearch(hosts=[config.elasticsearch_host], 
                   verify_certs=config.elasticsearch_verify_certs,
                   timeout=config.elasticsearch_timeout_secs)

s = Search(using=es, index=config.elasticsearch_index_name)
s = s.params(size=10000)
s.update_from_dict(get_query())

#Get the next batch of hits from Elasticsearch
stopwords = stopwords.words('english')
frequencies = {}
tweet_count = 0
for hit in s.scan():
    tweet_count += 1
    text, quoted_text = get_tweet_text(hit)
    count_word_freq(text, frequencies, stopwords)
    if quoted_text:
        count_word_freq(quoted_text, frequencies, stopwords)
    if tweet_count == args.maxcount:
        break

sorted_frequencies = dict(sorted(frequencies.items(), key=lambda item: item[1], reverse=True))

with open("keywords.txt", "w", encoding="utf-8") as f:
    f.write("Total tweets: %d" % tweet_count)
    f.write("\n\n")
    for kv in sorted_frequencies.items():
        f.write("%s: %d\n" % kv)
