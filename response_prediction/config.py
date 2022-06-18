"""
Config class containing all the settings for running summarizer server
"""

import jsonpickle

class Config(object):
    """Container for summarizer server settings.

    """
    def __init__(self):
        """Initializes the Config instance.
        """
        #Model settings
        self.model_path = ""
        self.use_large_tfhub_url = ""
        self.sbert_model_name = ""
        self.sbert_max_seq_length = 512
        self.embedding_type = "use_large"
        self.generate_batch_size = 32
        self.embed_batch_size = 32
        self.embed_enabled = True
        self.sentiment_batch_size = 32
        self.sentiment_modelpath = ""
        self.sentiment_max_seq_length = 512

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
