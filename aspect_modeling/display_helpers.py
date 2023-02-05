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

def build_topic_dataframes(cluster_assignments, cluster_keywords, cluster_tfidf_scores, cluster_coherence):
    topics_data = {}
    metrics_data = {"Cluster": [], "Avg_TF-IDF": []}
    for coherence_metric in cluster_coherence:
        metrics_data[f"Coherence_{coherence_metric}"] = []
        
    cluster_ids = np.unique(cluster_assignments)+1
    for i, cluster_id in enumerate(cluster_ids):
        topics_data[f"Cluster_{cluster_id}"] = cluster_keywords[i]
        topics_data[f"TF-IDF_{cluster_id}"] = cluster_tfidf_scores[i]
        metrics_data["Cluster"].append(f"Cluster_{cluster_id}")
        metrics_data["Avg_TF-IDF"].append(np.mean(cluster_tfidf_scores[i]))
        for coherence_metric in cluster_coherence:
            metrics_data[f"Coherence_{coherence_metric}"].append(cluster_coherence[coherence_metric][i])
    topics_df = pd.DataFrame.from_dict(topics_data)
    metrics_df = pd.DataFrame.from_dict(metrics_data)
    metrics_df = metrics_df.set_index("Cluster")
    metrics_df.loc["Avg."] = metrics_df.mean()
    return topics_df, metrics_df