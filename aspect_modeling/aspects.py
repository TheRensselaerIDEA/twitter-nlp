import numpy as np
from elasticsearch import Elasticsearch
from elasticsearch_dsl import Search
from textwrap import wrap

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

def get_query(embedding_type, query_embedding):
    query = {
        "_source": ["id_str", "text", "extended_tweet.full_text", "quoted_status.text", 
                    "quoted_status.extended_tweet.full_text", f"embedding.{embedding_type}.primary"],
        "query": {
            "script_score": {
                "query": {
                    "bool": {
                        "filter": [{
                            "exists": {
                                "field": f"embedding.{embedding_type}.quoted"
                            }
                        }, {
                            "exists": {
                                "field": f"embedding.{embedding_type}.primary"
                            }
                        }]
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

def run_query(es_uri, es_index, embedding_type, embedding_model, query, max_results=1000):
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
        s.update_from_dict(get_query(embedding_type, query_embedding))

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