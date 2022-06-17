"""
Config class containing all the settings for running embedder tool
"""

import jsonpickle

class Config(object):
    """Container for embedder tool settings.

    """
    def __init__(self):
        """Initializes the Config instance.
        """
        #Elasticsearch settings
        self.elasticsearch_host = ""
        self.elasticsearch_verify_certs = False
        self.elasticsearch_index_name = ""
        self.elasticsearch_batch_size = 500
        self.elasticsearch_timeout_secs = 30

        #Embedding settings
        self.use_large_tfhub_url = ""
        self.use_large_batch_size = 128
        self.sbert_model_name = ""
        self.sbert_batch_size = 128
        self.bert_max_seq_length = 512
        self.embedding_type="use_large"

        #Processing settings
        self.sleep_idle_secs = 5
        self.sleep_not_idle_secs = 0.01
        self.log_level = "ERROR"

    @staticmethod
    def load(filepath):
        """Loads the config from a JSON file.

        Args:
            filepath: path of the JSON file.
        """
        with open(filepath, "r") as file:
            json = file.read()
        config = jsonpickle.decode(json)
        return config