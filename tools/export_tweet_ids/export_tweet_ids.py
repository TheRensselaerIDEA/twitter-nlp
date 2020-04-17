import argparse
import time
import os
import export_tweet_ids_helpers
from datetime import datetime, timedelta
from elasticsearch import Elasticsearch
from elasticsearch_dsl import Search

from config import Config

#load the args & config
parser = argparse.ArgumentParser("Run the tweet id exporter")
parser.add_argument("--configfile", "-c", default="config.json", required=False, help="Path to the config file to use.")
parser.add_argument("--exportdir", "-d", default="tweet_ids", required=False, help="Path of directory to export the tweet id lists to.")
parser.add_argument("--mode", "-m", required=False, default="originals-only", help="Export mode [all, originals-only]")
parser.add_argument("--startdate", "-s", required=True, help="Start date yyyy-MM-dd of the query to export Ids for (inclusive).")
parser.add_argument("--enddate", "-e", required=True, help="End date yyyy-MM-dd of the query to export Ids for (inclusive).")
args = parser.parse_args()

print()
print("Running with arguments:")
print(args)
print()

config = Config.load(args.configfile)

mode = args.mode.lower()
if mode not in set(["all", "originals-only"]):
  raise ValueError("Invalid mode. See param --mode help.")

startdate = datetime.strptime(args.startdate, "%Y-%m-%d")
enddate = datetime.strptime(args.enddate, "%Y-%m-%d")
if startdate > enddate:
  raise ValueError("--enddate must be greater than or equal to --startdate.")

es = Elasticsearch(hosts=[config.elasticsearch_host], 
                     verify_certs=config.elasticsearch_verify_certs,
                     timeout=config.elasticsearch_timeout_secs)

total_count = 0
current_time = startdate
while current_time < enddate + timedelta(days=1):
  current_range_start = current_time
  current_range_end = current_time + timedelta(hours=1)
  
  #make sure the month folder exists
  month_dir = os.path.join(args.exportdir, current_range_start.strftime("%Y-%m"))
  if not os.path.isdir(month_dir):
    os.makedirs(month_dir, exist_ok=True)

  #query the data for the range & write the file
  s = Search(using=es, index=config.elasticsearch_index_name)
  s = s.params(preserve_order=True)
  query = export_tweet_ids_helpers.get_query(mode, current_range_start, current_range_end)
  s.update_from_dict(query)

  hour_file = os.path.join(month_dir, "tweet-ids-{0}.txt".format(current_range_start.strftime("%Y-%m-%d-%H")))
  file = None
  for i,hit in enumerate(s.scan()):
    total_count += 1
    tweet_id = hit.meta["id"]
    if (i == 0):
      file = open(hour_file, "w", encoding="utf-8")
    else:
      file.write('\n')
    file.write(tweet_id)

  if file is not None:
    file.close()

  print("{0} range ({1} <= t < {2}). Cumulative total so far: {3}".format(
    "Exported" if file is not None else "Nothing in",
    current_range_start, 
    current_range_end, 
    total_count))

  #increment the range by an hour
  current_time += timedelta(hours=1)
  time.sleep(0.01)