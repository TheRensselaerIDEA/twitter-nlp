import argparse
import time
import reindex_helpers

from config import Config
from elasticsearch import Elasticsearch
from elasticsearch_dsl import Search

def start():
    #load the args & config
    parser = argparse.ArgumentParser("Run the reindex script")
    parser.add_argument("--sourceindex", "-s", required=True, help="Source index to copy data from.")
    parser.add_argument("--configfile", "-c", default="config.json", required=False, help="Path to the config file to use.")
    parser.add_argument("--reqpersec", "-r", type=int, default=-1, required=False, help="Num requests per second to throttle the reindex task.")
    parser.add_argument("--slices", default="auto", required=False, help="Num of parallel slices to split the reindex task into. 'auto' lets Elasticsearch choose.")
    parser.add_argument("--verify", "-v", action="store_true", required=False, help="Verify the diff between source and target indices instead of running the reindex")
    args = parser.parse_args()

    print()
    print("Running with arguments:")
    print(args)
    print()

    config = Config.load(args.configfile)
        
    print("Using '{0}' as source index and '{1}' as target index.".format(args.sourceindex, config.elasticsearch_index_name))
    print()

    es = Elasticsearch(hosts=[config.elasticsearch_host], 
                        verify_certs=config.elasticsearch_verify_certs,
                        timeout=config.elasticsearch_timeout_secs)

    if args.verify:
        #verifying the data
        print ("Verifying data...")
        print()

        source_search = Search(using=es, index=args.sourceindex)
        source_search_query = { "match_all": {}} if config.elasticsearch_query is None else config.elasticsearch_query
        source_search = source_search.update_from_dict({
            "_source": False,
            "query" : source_search_query
        })
        scan_size = 10000
        source_search = source_search.params(size=scan_size)

        source_total = 0
        target_total = 0
        source_ids = []
        
        for hit in source_search.scan():
            source_total += 1
            source_ids.append(hit.meta["id"])

            if source_total % scan_size == 0:
                target_total += reindex_helpers.verify_target_docs(es, config, source_ids, scan_size)
                source_ids.clear()
                print("Verified {0} source documents and {1} target documents...".format(source_total, target_total))
                time.sleep(0.01)
        
        if len(source_ids) > 0:
            target_total += reindex_helpers.verify_target_docs(es, config, source_ids, scan_size)

        print()
        print("Verify complete. Source total: {0}. Target total: {1}. (should be equal after successful reindex)"
                .format(source_total, target_total))

    else:
        #reindexing the data
        print("Reindexing data...")
        print()

        reindex_body = {
            "source": {
                "index": args.sourceindex
            },
            "dest": {
                "index": config.elasticsearch_index_name
            }
        }
        if config.elasticsearch_query is not None:
            reindex_body["source"]["query"] = config.elasticsearch_query

        res = es.reindex(reindex_body, max_docs=config.max_docs, wait_for_completion=False, refresh=True, requests_per_second=args.reqpersec, slices=args.slices)

        task_id = res["task"]
        print(task_id)
        while True:
            task = es.tasks.get(task_id)

            status = task["task"]["status"]
            total = status["total"]
            created = status["created"]
            updated = status["updated"]
            deleted = status["deleted"]
            processed = created + updated + deleted
            batches = status["batches"]
            print("{0} batches complete - processed {1}/{2} documents.".format(batches, processed, total))

            if task["completed"] == True:
                failures = task["response"]["failures"]
                print()
                print("Reindexing complete with {0} failure(s).".format(len(failures)))
                print("Created: {0}; Updated: {1}; Deleted: {2}; Total: {3}".format(created, updated, deleted, processed))
                if (len(failures) > 0):
                    print()
                    print("The following failures occurred:")
                    print()
                    for fail in failures:
                        print(fail)
                break

            time.sleep(5)

if __name__ == "__main__":
    start()