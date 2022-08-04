from multiprocessing.sharedctypes import Value
import plotly.graph_objects as go
import streamlit as st
import tensorflow_hub as hub
import tensorflow as tf
from itertools import compress
from sentence_transformers import SentenceTransformer

from aspects import run_query, compute_aspect_similarities

title = "Aspect-driven Twitter Response Analysis"
st.set_page_config(
    page_title=title,
    page_icon="📊",
    layout="wide"
)

es_indices = {
    "coronavirus-data-all-lite": {
        "embedding_type": "use_large",
        "example_query": "Shut down the schools!",
        "example_aspects": ["child safety", "saving the economy"]
    },
    "coronavirus-data-masks": {
        "embedding_type": "use_large",
        "example_query": "Why should I wear a mask?",
        "example_aspects": ["protecting others", "personal freedom"]
    },
    "coronavirus-data-pubhealth-quotes": {
        "embedding_type": "sbert",
        "example_query": "Stay home, stay safe.",
        "example_aspects": ["CDC can't be trusted", "flatten the curve"]
    },
    "opioids-data-all": {
        "embedding_type": "use_large",
        "example_query": "Heroine",
        "example_aspects": ["can't stop", "stay away"]
    },
    "ukraine-data-lite": {
        "embedding_type": "sbert",
        "example_query": "US should arm Ukraine with fighter jets.",
        "example_aspects": ["risks of getting involved", "Russian war crimes"]
    },
    "vaccine-data-pubhealth-quotes": {
        "embedding_type": "sbert",
        "example_query": "Pregnant women should get vaccinated.",
        "example_aspects": ["risks to baby", "COVID while pregnant"]
    }
}

@st.cache(allow_output_mutation=True, max_entries=2)
def get_embedding_model(embedding_type):
    if embedding_type == "sbert":
        embedding_model = SentenceTransformer("all-MiniLM-L12-v2")
    elif embedding_type == "use_large":
        # prevent TensorFlow from allocating the entire GPU just to load the embedding model
        gpus = tf.config.list_physical_devices("GPU")
        for gpu in gpus:
            tf.config.experimental.set_memory_growth(gpu, True)
        embedding_model = hub.load("https://tfhub.dev/google/universal-sentence-encoder-large/5")
    else:
        raise ValueError(f"Unsupported embedding type '{embedding_type}'.")
    return embedding_model

@st.cache(allow_output_mutation=True, max_entries=1)
def get_query_results(es_index, embedding_type, query, max_results):
    embedding_model = get_embedding_model(embedding_type)
    query_results = run_query(
        "https://localhost:8080/elasticsearch/", 
        es_index, 
        embedding_type,
        embedding_model, 
        query, 
        max_results=max_results)
    return query_results

@st.cache(allow_output_mutation=True, max_entries=1)
def get_aspect_similarities(tweet_embeddings, embedding_type, aspects):
    embedding_model = get_embedding_model(embedding_type)
    aspect_similarities = compute_aspect_similarities(
        tweet_embeddings, embedding_type, embedding_model, aspects)
    return aspect_similarities

def run():
    # Step 1: Collect query and aspect parameters
    with st.sidebar:
        st.title(title)
        query_tab, aspects_tab, clustering_tab = st.tabs(["Query", "Aspects", "Clustering"])
        with query_tab:
            es_index = st.selectbox("Elasticsearch Index *", 
                                    sorted(es_indices.keys()), 
                                    key="elasticsearch_index")
            query = st.text_input("Find responses to tweets similar to: *", 
                                  key="query", 
                                  value=es_indices[es_index]["example_query"])
            max_results = st.slider("Max Results *", 500, 10000, key="max_results", 
                                    value=5000, step=500)
            min_query_similarity = st.slider("Min Query Similarity", -1.0, 1.0, key="min_query_similarity", 
                                              value=0.25, step=0.05)
            st.markdown('<span style="color: red">*: changing causes query to re-run.</span>', unsafe_allow_html=True)

        with aspects_tab:
            aspect_defaults = es_indices[es_index]["example_aspects"]
            aspects = [st.text_input(f"Aspect {i+1}:", key=f"aspect_{i+1}", value=aspect_defaults[i]) 
                       for i in range(2)]
            min_aspect_similarity = st.slider("Min Aspect Similarity", -1.0, 1.0, key="min_aspect_similarity", 
                                              value=0.25, step=0.05)

        with clustering_tab:
            st.subheader("Coming soon!")

    # Step 2: Execute the query and compute aspect similarities
    # (results are cached for unchanged query and aspect parameters)
    embedding_type = es_indices[es_index]["embedding_type"]
    tweet_text, tweet_embeddings, tweet_scores = get_query_results(es_index, embedding_type, query, max_results)
    aspect_similarities = get_aspect_similarities(tweet_embeddings, embedding_type, aspects)
    
    # Step 3: Display the results
    with st.expander("Results", expanded=True):
        st.markdown(f"**Index:** {es_index}; &nbsp;&nbsp; "
                    f"**Query:** \"{query}\"", unsafe_allow_html=True)
        min_query_similarity_filter = tweet_scores >= min_query_similarity
        min_aspect_similarity_filter = (aspect_similarities >= min_aspect_similarity).any(axis=-1)
        combined_filter = min_query_similarity_filter & min_aspect_similarity_filter

        filtered_aspect_similarities = aspect_similarities[combined_filter]
        filtered_tweet_text = list(compress(tweet_text, combined_filter))
        
        results_plot = go.Figure()
        results_plot.layout.margin = go.layout.Margin(b=0, l=0, r=0, t=30)
        results_plot.update_layout(xaxis_title=aspects[0], yaxis_title=aspects[1])
        results_plot.add_trace(go.Scatter(x=filtered_aspect_similarities[:, 0],
                                            y=filtered_aspect_similarities[:, 1],
                                            mode="markers",
                                            hoverinfo="text",
                                            hovertext=filtered_tweet_text))
        st.plotly_chart(results_plot, use_container_width=True)

if __name__ == "__main__":
    run()