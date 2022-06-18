"""
Config class containing all the settings for running keyword analyzer
"""

import jsonpickle

class Config(object):
    """Container for keyword analyzer tool settings.

    """
    def __init__(self):
        """Initializes the Config instance.
        """
        #Elasticsearch settings
        self.elasticsearch_host = ""
        self.elasticsearch_verify_certs = False
        self.elasticsearch_index_name = ""
        self.elasticsearch_timeout_secs = 30

        #Processing settings
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