from config import Config
from elasticsearch import Elasticsearch

def verify_or_setup_index(config):
    es = Elasticsearch(hosts=[config.elasticsearch_host], 
                   verify_certs=config.elasticsearch_verify_certs)
    
    index_exists = es.indices.exists(config.elasticsearch_index_name)
    #Do nothing if the index exists
    if index_exists:
        return "Index '{0}' found.".format(config.elasticsearch_index_name)
    
    #Create if the index does not exist
    mappings = {
        "properties": {
            "created_at": {
                "type": "date",
                "format": "EEE MMM dd HH:mm:ss Z yyyy"
            },
            "coordinates.coordinates": {
                "type": "geo_point"
            },
            "place.bounding_box": {
                "type": "geo_shape",
                "coerce": True,
                "ignore_malformed": True
            },
            "user.created_at": {
                "type": "date",
                "format": "EEE MMM dd HH:mm:ss Z yyyy"
            },
            "quoted_status.created_at": {
                "type": "date",
                "format": "EEE MMM dd HH:mm:ss Z yyyy"
            },
            "quoted_status.coordinates.coordinates": {
                "type": "geo_point"
            },
            "quoted_status.place.bounding_box": {
                "type": "geo_shape",
                "coerce": True,
                "ignore_malformed": True
            },
            "quoted_status.user.created_at": {
                "type": "date",
                "format": "EEE MMM dd HH:mm:ss Z yyyy"
            }
        }
    }
    if config.elasticsearch_compat_mode:
        #prior to ES 7, document types were expected in the mappings
        mappings = {
            "_doc": mappings
        }
    else:
        #dense_vector not supported until ES 7
        mappings["properties"]["embedding.use_large"] = {
            "type": "dense_vector",
            "dims": 512
        }
        mappings["properties"]["embedding.quoted.use_large"] = {
            "type": "dense_vector",
            "dims": 512
        }
        mappings["properties"]["embedding.quoted_concat.use_large"] = {
            "type": "dense_vector",
            "dims": 512
        }

    es.indices.create(config.elasticsearch_index_name, {
        "mappings": mappings
    })

    return "Index '{0}' created.".format(config.elasticsearch_index_name)