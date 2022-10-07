"""
Utility methods for clustering.
"""

from sklearn.cluster import KMeans
from sklearn.metrics import silhouette_score
from kneed import KneeLocator
import numpy as np
from tqdm import trange

def get_silhouette_score(embeddings, cluster_assignments):
    score = silhouette_score(embeddings, cluster_assignments)
    return score

def detect_optimal_clusters(embeddings, k_range=(1,30), n_init=10, max_iter=300, 
                            random_state=None, show_progress=False, plot_elbow=False):
    # Determine actual k-range. The max can't be higher than the number of embeddings
    # and must also be greater than or equal to the min.
    min_k, max_k = k_range
    max_k = min(max_k, embeddings.shape[0])
    if max_k < min_k:
        min_k = max_k
    
    # Test all k in the k-range and gather the results
    kmeans_dict = {}
    for k in trange(min_k, max_k+1, 1, desc="KMeans n_clusters", disable=not show_progress):
        kmeans = KMeans(n_clusters=k, n_init=n_init, max_iter=max_iter, random_state=random_state)
        kmeans.fit(embeddings)
        kmeans_dict[k] = kmeans
    
    # Detect the elbow and optionally plot it, 
    # then select the KMeans instance with the optmal k
    x = np.arange(min_k, max_k+1)
    y = np.array([kmeans.inertia_ for _, kmeans in kmeans_dict.items()])
    kneedle = KneeLocator(x, y, curve="convex", direction="decreasing", 
                          online=True, interp_method="polynomial")
    if kneedle.elbow:
        optimal_k = round(kneedle.elbow)
        if plot_elbow:
            kneedle.plot_knee()
            kneedle.plot_knee_normalized()
    else:
        #Fallback to KMeans default, or closest value in the k-range (this shouldn't really happen)
        print("Could not find optimal k using elbow method. Falling back to KMeans default.")
        optimal_k = 8 
        if optimal_k < min_k:
            optimal_k = min_k
        elif optimal_k > max_k:
            optimal_k = max_k
   
    return kmeans_dict[optimal_k]
    