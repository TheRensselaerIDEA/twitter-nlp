from flask import Flask
from flask_restful import Resource, Api
from clean_text import clean_text
from config import Config
import tensorflow_hub as hub
import numpy as np
import argparse

parser = argparse.ArgumentParser("Run the embedder service")
parser.add_argument("--configfile", "-c", default="config.json", required=False, help="Path to the config file to use.")
parser.add_argument("--port", "-p", default="8080", required=False, type=int, help="Port to run server on.")
args = parser.parse_args()

print()
print("Running with arguments:")
print(args)
print()

config = Config.load(args.configfile)

use_large = hub.load(config.use_large_tfhub_url)

app = Flask(__name__)
api = Api(app)

class Embedding(Resource):
    def get(self, model, text):
        if model.lower() == "use_large":
            text = clean_text(text)
            vecs = np.array(use_large([text]))
            return {
                "use_large": vecs[0].tolist()
            }
        else:
            return {
                "error": "unknown model"
            }

api.add_resource(Embedding, "/embed/<string:model>/<string:text>")
app.run(debug=False, port=args.port, host="0.0.0.0")