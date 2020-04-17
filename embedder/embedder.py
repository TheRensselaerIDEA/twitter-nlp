import argparse
import numpy as np
import embedder_helpers
import tensorflow_hub as hub
import math
import time
import logging
from elasticsearch import Elasticsearch
from elasticsearch.helpers import bulk
from elasticsearch_dsl import Search
from clean_text import clean_text

from config import Config

parser = argparse.ArgumentParser("Run the embedder service")
parser.add_argument("--configfile", "-c", default="config.json", required=False, help="Path to the config file to use.")
parser.add_argument("--logfile", "-l", default="embedderlog.txt", required=False, help="Path to the log file to write to.")
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

#Load embedding model
use_large = hub.load(config.use_large_tfhub_url)

#Initialize elasticsearch settings
es = Elasticsearch(hosts=[config.elasticsearch_host], 
                   verify_certs=config.elasticsearch_verify_certs,
                   timeout=config.elasticsearch_timeout_secs)

#Poll for docs that need embedding
print("Polling for unembedded docs in Elasticsearch...")
print()
logging.info("Starting poller...")
while True:
    try:
        s = Search(using=es, index=config.elasticsearch_index_name)
        s = s.params(size=config.elasticsearch_batch_size)
        s.update_from_dict(embedder_helpers.get_query())
        
        #Get the next batch of hits from Elasticsearch
        hits = s.execute()

        if len(hits) == 0:
            #Sleep - idle
            logging.info("No unembedded docs found. Going to sleep (idle)...")
            time.sleep(config.sleep_idle_secs)
            continue

        logging.info("Found {0} unembedded docs. Preparing to embed by cleaning text...".format(len(hits)))
        embed_ids = []
        embed_text = []
        for hit in hits:
            hit_id = hit.meta["id"]
            text, quoted_text = embedder_helpers.get_tweet_text(hit)

            #clean the text
            text = clean_text(text)
            embed_text.append(text)
            embed_ids.append(hit_id)

            if quoted_text is not None:
                quoted_text = clean_text(quoted_text)
                quoted_concat_text = "{0} {1}".format(quoted_text, text)

                embed_text.append(quoted_text)
                embed_text.append(quoted_concat_text)
                embed_ids.append(hit_id)
                embed_ids.append(hit_id)

        #Embed with use_large
        n_batches = math.ceil(len(embed_ids) / config.use_large_batch_size)
        logging.info("Embedding {0} strings in {1} unembedded docs with Universal Sentence Encoder in {2} batches..."
                    .format(len(embed_ids), len(hits), n_batches))
        batches = [None] * n_batches
        for i in range(n_batches):
            start = i * config.use_large_batch_size
            end = start + config.use_large_batch_size
            batch_vecs = np.array(use_large([t for t in embed_text[start:end]]))
            batches[i] = batch_vecs

        vecs = np.concatenate(batches, axis=0)

        #Generate Elasticsearch bulk updates
        i = 0
        updates = []
        while i < len(embed_ids):
            hit_id = embed_ids[i]
            action = {
                "_op_type": "update",
                "_id": hit_id,
                "doc": {
                    "embedding": {
                        "use_large": {
                            "primary": vecs[i].tolist()
                        }
                    }
                }
            }
            i += 1
            if i < len(embed_ids) and embed_ids[i] == hit_id:
                action["doc"]["embedding"]["use_large"]["quoted"] = vecs[i].tolist()
                i += 1
            if i < len(embed_ids) and embed_ids[i] == hit_id:
                action["doc"]["embedding"]["use_large"]["quoted_concat"] = vecs[i].tolist()
                i += 1
            updates.append(action)
        
        #Sanity check
        if len(updates) != len(hits):
            raise RuntimeError("Number of updates {0} is not equal to the number of hits {1}.".format(len(updates), len(hits)))

        #Issue the bulk update request
        logging.info("Making bulk request to Elasticsearch with {0} update actions...".format(len(updates)))
        bulk(es, updates, index=config.elasticsearch_index_name, chunk_size=len(updates))

        #Sleep - not idle
        logging.info("Updates completed successfully. Going to sleep (not idle)...")
        time.sleep(config.sleep_not_idle_secs)

    except Exception as ex:
        logging.exception("Exception occurred while polling or processing a batch.")