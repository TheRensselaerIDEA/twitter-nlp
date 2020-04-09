from elasticsearch_dsl import Search

def verify_target_docs(es, config, source_ids, scan_size):
    target_search = Search(using=es, index=config.elasticsearch_index_name)
    target_search = target_search.update_from_dict({
        "_source": False,
        "query": {
            "ids": {
                "values": source_ids
            }
        }
    })
    target_search = target_search.params(size=scan_size)
    r = target_search.execute()
    return len(r.hits.hits)