import numpy as np
import pandas as pd

def format_date_range(date_range):
    if not date_range:
        return ""
    date_range = tuple(d.strftime('%m/%d/%Y') for d in date_range)
    if len(date_range) == 1:
        return f"$\geq$ {date_range[0]}"
    if date_range[0] == date_range[1]:
        return date_range[0]
    return f"{date_range[0]} - {date_range[1]}"

def build_topic_dataframes(cluster_assignments, cluster_keywords, cluster_tfidf_scores):
    topics_data = {}
    avg_tfidf_data = {"Cluster": [], "Avg_TF-IDF": []}
    cluster_ids = np.unique(cluster_assignments)+1
    for i, cluster_id in enumerate(cluster_ids):
        topics_data[f"Cluster_{cluster_id}"] = cluster_keywords[i]
        topics_data[f"TF-IDF_{cluster_id}"] = cluster_tfidf_scores[i]
        avg_tfidf_data["Cluster"].append(cluster_id)
        avg_tfidf_data["Avg_TF-IDF"].append(np.mean(cluster_tfidf_scores[i]))
    topics_df = pd.DataFrame.from_dict(topics_data)
    avg_tfidf_df = pd.DataFrame.from_dict(avg_tfidf_data)
    return topics_df, avg_tfidf_df