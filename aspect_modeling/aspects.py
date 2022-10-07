import numpy as np
from datetime import datetime
from hdbscan import HDBSCAN
from sklearn.cluster import KMeans
from elasticsearch import Elasticsearch
from elasticsearch_dsl import Search
from textwrap import wrap

import cluster_helpers 

def text_wrap(text):
    return "<br>".join(wrap(text, width=80))

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

def get_base_filters(embedding_type):
    return [{
        "exists": {
            "field": f"embedding.{embedding_type}.quoted"
        }
    }, {
        "exists": {
            "field": f"embedding.{embedding_type}.primary"
        }
    }]

def get_query(embedding_type, query_embedding, date_range):
    additional_filters = []
    if len(date_range) > 0:
        additional_filters.append({
            "range": {
                "created_at": {
                    "format": "strict_date",
                    "time_zone": "+00:00",
                    "gte": date_range[0].strftime("%Y-%m-%d")
                }
            }
        })
        if len(date_range) > 1:
            additional_filters[-1]["range"]["created_at"]["lte"] = date_range[1].strftime("%Y-%m-%d")

    query = {
        "_source": ["id_str", "text", "extended_tweet.full_text", "quoted_status.text", 
                    "quoted_status.extended_tweet.full_text", f"embedding.{embedding_type}.primary"],
        "query": {
            "script_score": {
                "query": {
                    "bool": {
                        "filter": get_base_filters(embedding_type) + additional_filters
                    }
                },
                "script": {
                    "source": f"dotProduct(params.query_vector, 'embedding.{embedding_type}.quoted') + 1.0",
                    "params": {"query_vector": query_embedding.tolist()}
                }
            }
        }
    }
    return query

def run_query(es_uri, es_index, embedding_type, embedding_model, query, date_range, max_results=1000):
    # Embed query
    if embedding_type == "sbert":
        query_embedding = embedding_model.encode(query, normalize_embeddings=True)
    elif embedding_type == "use_large":
        query_embedding = embedding_model([query]).numpy()[0]
    else:
        raise ValueError(f"Unsupported embedding type '{embedding_type}'.")

    # Use query embeddings to get responses to similar tweets
    with Elasticsearch(hosts=[es_uri], timeout=60, verify_certs=False) as es:
        s = Search(using=es, index=es_index)
        s = s.params(size=max_results)
        s.update_from_dict(get_query(embedding_type, query_embedding, date_range))

        tweet_text = []
        tweet_embeddings = []
        tweet_scores = []
        for hit in s.execute():
            tweet_embeddings.append(np.array(hit["embedding"][embedding_type]["primary"]))
            text, quoted_text = get_tweet_text(hit)
            tweet_text.append(f"Tweet:<br>----------<br>{text_wrap(quoted_text)}<br><br>"
                              f"Response:<br>----------<br>{text_wrap(text)}")
            tweet_scores.append(hit.meta.score-1.0)
            if len(tweet_embeddings) == max_results:
                break

        tweet_embeddings = np.vstack(tweet_embeddings)
        tweet_scores = np.array(tweet_scores)

    return tweet_text, tweet_embeddings, tweet_scores

def get_index_date_boundaries(es_uri, es_index, embedding_type):
    with Elasticsearch(hosts=[es_uri], timeout=60, verify_certs=False) as es:
        s = Search(using=es, index=es_index)
        s = s.params(size=0)
        s.update_from_dict({
            "query": {
                "bool": {"filter": get_base_filters(embedding_type)}
            },
            "aggs": {
                "min_date": {"min": {"field": "created_at", "format": "strict_date"}},
                "max_date": {"max": {"field": "created_at", "format": "strict_date"}}
            }
        })
        results = s.execute()
    min_date = datetime.strptime(results.aggregations.min_date.value_as_string, "%Y-%m-%d").date()
    max_date = datetime.strptime(results.aggregations.max_date.value_as_string, "%Y-%m-%d").date()
    return min_date, max_date

def compute_aspect_similarities(tweet_embeddings, embedding_type, embedding_model, aspects):
    # Embed aspects
    if embedding_type == "sbert":
        aspect_embeddings = embedding_model.encode(aspects, normalize_embeddings=True)
    elif embedding_type == "use_large":
        aspect_embeddings = embedding_model(aspects).numpy()
    else:
        raise ValueError(f"Unsupported embedding type '{embedding_type}'.")

    # Compute aspect similarity vector for each response.
    # Matrix multiplication will give cosine similarities
    # since all embeddings are normalized to unit sphere.
    aspect_similarities = tweet_embeddings @ aspect_embeddings.T

    return aspect_similarities

def cluster_aspect_similarities(aspect_similarities, clustering_type, kmeans_n_clusters, 
                                hdbscan_min_cluster_size, hdbscan_min_samples):
    if clustering_type == "kmeans":
        if kmeans_n_clusters > 0:
            kmeans_n_clusters = min(kmeans_n_clusters, aspect_similarities.shape[0])
            kmeans = KMeans(n_clusters=kmeans_n_clusters)
            kmeans.fit(aspect_similarities)
        else:
            kmeans = cluster_helpers.detect_optimal_clusters(aspect_similarities)
        cluster_assignments = kmeans.predict(aspect_similarities)
    elif clustering_type == "hdbscan":
        hdbscan = HDBSCAN(min_cluster_size=hdbscan_min_cluster_size,
                          min_samples=hdbscan_min_samples)
        cluster_assignments = hdbscan.fit_predict(aspect_similarities)
    else:
        raise ValueError(f"Unsupported clustering type '{clustering_type}'.")

    silhouette_score = cluster_helpers.get_silhouette_score(aspect_similarities, cluster_assignments)
    return cluster_assignments, silhouette_score