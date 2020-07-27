"""
Config class containing all the settings for running reindex tool
"""

import jsonpickle

class Config(object):
    """Container for reindex tool settings.

    """
    def __init__(self):
        """Initializes the Config instance.
        """
        #Elasticsearch settings
        self.elasticsearch_host = ""
        self.elasticsearch_verify_certs = False
        self.elasticsearch_index_name = ""
        self.elasticsearch_timeout_secs = 30
        self.elasticsearch_query = None

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