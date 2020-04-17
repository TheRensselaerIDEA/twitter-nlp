"""
Config class containing all the settings for running twitter monitor
"""

import jsonpickle

class Config(object):
    """Container for twitter monitor settings.

    """
    def __init__(self):
        """Initializes the Config instance.
        """
        #Auth settings
        self.api_key = ""
        self.api_secret_key = ""
        self.access_token = ""
        self.access_token_secret = ""

        #Elasticsearch settings
        self.elasticsearch_host = ""
        self.elasticsearch_verify_certs = False
        self.elasticsearch_index_name = ""
        self.elasticsearch_compat_mode = False
        self.elasticsearch_batch_size = 500
        self.elasticsearch_timeout_secs = 30

        #logging and error handling settings
        self.log_level = "ERROR"
        self.restart_attempts = 5
        self.restart_wait_secs = 60

        #filter settings
        self.filter_languages = []
        self.filter_keywords = []

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