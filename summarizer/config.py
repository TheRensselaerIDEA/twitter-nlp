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
        self.transformers_models = []
        self.batch_size = 32

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