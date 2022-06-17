import argparse
import sentiment_helpers
import time
import logging
import torch
from vaderSentiment.vaderSentiment import SentimentIntensityAnalyzer
from transformers import AutoModelForSequenceClassification, AutoTokenizer
from elasticsearch import Elasticsearch
from elasticsearch.helpers import bulk
from elasticsearch_dsl import Search

from config import Config

parser = argparse.ArgumentParser("Run the sentiment scoring service")
parser.add_argument("--configfile", "-c", default="config.json", required=False, help="Path to the config file to use.")
parser.add_argument("--logfile", "-l", default="sentimentlog.txt", required=False, help="Path to the log file to write to.")
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

#Load vader sentiment intensity analyzer
vader = SentimentIntensityAnalyzer()

#Load sentiment classification model
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
print(device)
sentiment_tokenizer = AutoTokenizer.from_pretrained(config.sentiment_modelpath)
sentiment_model = AutoModelForSequenceClassification.from_pretrained(config.sentiment_modelpath)
sentiment_model.to(device)

#Initialize elasticsearch settings
es = Elasticsearch(hosts=[config.elasticsearch_host], 
                   verify_certs=config.elasticsearch_verify_certs,
                   timeout=config.elasticsearch_timeout_secs)

#Poll for docs that need sentiment
print("Polling for unscored docs in Elasticsearch...")
print()
logging.info("Starting poller...")
while True:
    try:
        s = Search(using=es, index=config.elasticsearch_index_name)
        s = s.params(size=config.elasticsearch_batch_size)
        s.update_from_dict(sentiment_helpers.get_query())
        
        #Get the next batch of hits from Elasticsearch
        hits = s.execute()

        if len(hits) == 0:
            #Sleep - idle
            logging.info("No unscored docs found. Going to sleep (idle)...")
            time.sleep(config.sleep_idle_secs)
            continue

        #Run sentiment analysis on the batch
        logging.info("Found {0} unscored docs. Calculating sentiment scores with Vader...".format(len(hits)))
        updates = []
        for hit in hits:
            text, quoted_text = sentiment_helpers.get_tweet_text(hit)
            text = sentiment_helpers.clean_text_for_vader(text)
            action = {
                "_op_type": "update",
                "_id": hit.meta["id"],
                "doc": {
                    "sentiment": {
                        "vader": {
                            "primary": vader.polarity_scores(text)["compound"]
                        },
                        "roberta": {
                            "primary": sentiment_helpers.get_sentiment([text], 1, 
                                            config.sentiment_max_seq_length, 
                                            sentiment_model, sentiment_tokenizer, device).item()
                        }
                    }
                }
            }
            if quoted_text is not None:
                quoted_text = sentiment_helpers.clean_text_for_vader(quoted_text)
                quoted_concat_text = "{0} {1}".format(quoted_text, text)
                action["doc"]["sentiment"]["vader"]["quoted"] = vader.polarity_scores(quoted_text)["compound"]
                action["doc"]["sentiment"]["vader"]["quoted_concat"] = vader.polarity_scores(quoted_concat_text)["compound"]

                action["doc"]["sentiment"]["roberta"]["quoted"] = sentiment_helpers.get_sentiment([quoted_text], 1, 
                                                                        config.sentiment_max_seq_length,
                                                                        sentiment_model, sentiment_tokenizer, device).item()
                action["doc"]["sentiment"]["roberta"]["quoted_concat"] = sentiment_helpers.get_sentiment([quoted_concat_text], 1, 
                                                                            config.sentiment_max_seq_length,
                                                                            sentiment_model, sentiment_tokenizer, device).item()

            updates.append(action)

        #Issue the bulk update request
        logging.info("Making bulk request to Elasticsearch with {0} update actions...".format(len(updates)))
        bulk(es, updates, index=config.elasticsearch_index_name, chunk_size=len(updates))

        #Sleep - not idle
        logging.info("Updates completed successfully. Going to sleep (not idle)...")
        time.sleep(config.sleep_not_idle_secs)

    except Exception as ex:
        logging.exception("Exception occurred while polling or processing a batch.")