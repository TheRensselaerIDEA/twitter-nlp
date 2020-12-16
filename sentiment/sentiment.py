import argparse
import sentiment_helpers
import time
import logging
from bert_eval import BertSentiment
from vaderSentiment.vaderSentiment import SentimentIntensityAnalyzer
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

bert = BertSentiment(config.model_path, config.model_config)

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
        logging.info("Found {0} unscored docs. Calculating sentiment scores with Vader and Bert...".format(len(hits)))
        texts, quoted_texts = zip(*map(sentiment_helpers.get_tweet_text, hits))
        texts = list(map(sentiment_helpers.clean_text_for_vader, texts))
        quoted = {index: quote for index, quote in map(lambda x: (x[0], sentiment_helpers.clean_text_for_vader(x[1])), filter(lambda y: y[1] is not None, enumerate(quoted_texts)))}
        quoted_concat = {index: "{0} {1}".format(quote, texts[index]) for index, quote in quoted.items()}
        
        # use bert to batch score text inputs
        bert_texts = bert.score(texts)
        bert_quoted = bert.score(list(quoted.values()))
        bert_concat = bert.score(list(quoted_concat.values()))
        bert_quoted = {key: val for key, val in zip(quoted.keys(), zip(*bert_quoted))}
        bert_concat = {key: val for key, val in zip(quoted_concat.keys(), zip(*bert_concat))}
        
        def create_update(hit):
            action = {
                "_op_type": "update",
                "_id": hit[1].meta["id"],
                "doc": {
                    "sentiment": {
                        "vader": {
                            "primary": vader.polarity_scores(texts[hit[0]])["compound"]
                        },
			"bert" : {
                            "scores": bert_texts[0][hit[0]],
                            "class": bert_texts[1][hit[0]],
                            "primary": bert_texts[2][hit[0]]
			}
                    }
                }
            }
            if hit[0] in quoted:
                action["doc"]["sentiment"]["vader"]["quoted"] = vader.polarity_scores(quoted_texts[hit[0]])["compound"]
                action["doc"]["sentiment"]["vader"]["quoted_concat"] = vader.polarity_scores(quoted_concat[hit[0]])["compound"]
                action["doc"]["sentiment"]["bert"]["quoted"] = bert_quoted[hit[0]][2]
                action["doc"]["sentiment"]["bert"]["quoted_scores"] = bert_quoted[hit[0]][0]
                action["doc"]["sentiment"]["bert"]["quoted_class"] = bert_quoted[hit[0]][1]
                action["doc"]["sentiment"]["bert"]["quoted_concat"] = bert_concat[hit[0]][2]
                action["doc"]["sentiment"]["bert"]["quoted_concat_scores"] = bert_concat[hit[0]][0]
                action["doc"]["sentiment"]["bert"]["quoted_concat_class"] = bert_concat[hit[0]][1]
            return action

        updates = list(map(create_update, enumerate(hits)))
        
        #Issue the bulk update request
        logging.info("Making bulk request to Elasticsearch with {0} update actions...".format(len(updates)))
        bulk(es, updates, index=config.elasticsearch_index_name, chunk_size=len(updates))

        #Sleep - not idle
        logging.info("Updates completed successfully. Going to sleep (not idle)...")
        time.sleep(config.sleep_not_idle_secs)

    except Exception as ex:
        logging.exception("Exception occurred while polling or processing a batch.")
