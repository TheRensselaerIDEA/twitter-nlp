from flask import Flask
from flask_restful import Resource, Api, reqparse
from config import Config
from transformers import BartTokenizer, BartForConditionalGeneration
import torch
import math
import argparse

parser = argparse.ArgumentParser("Run the summarizer service")
parser.add_argument("--configfile", "-c", default="config.json", required=False, help="Path to the config file to use.")
parser.add_argument("--port", "-p", default="8080", required=False, type=int, help="Port to run server on.")
args = parser.parse_args()

print()
print("Running with arguments:")
print(args)
print()

config = Config.load(args.configfile)

device = "cuda" if torch.cuda.is_available() else "cpu"
print(f"Device: {device}")

# Load Models
models = {}
for model_name in config.transformers_models:
    model = BartForConditionalGeneration.from_pretrained(model_name)
    tokenizer = BartTokenizer.from_pretrained(model_name)
    # Switch to cuda, eval mode, and FP16 for faster inference
    if device == "cuda":
        model = model.half()
    model.to(device)
    model.eval()

    models[model_name] = { "model": model, "tokenizer": tokenizer }

def summarize(original_text, max_len, num_beams, temperature, batch_size, model_name):
    if original_text is None or len(original_text) == 0:
        return []

    if model_name not in models:
        return ["No model loaded with name '{0}'".format(model_name)] * len(original_text)

    model = models[model_name]["model"]
    tokenizer = models[model_name]["tokenizer"]

    n_batches = math.ceil(len(original_text) / batch_size)
    batches = [None] * n_batches
    
    for i in range(n_batches):
        start = i * batch_size
        end = start + batch_size

        batch_text = original_text[start:end]

        inputs = tokenizer.batch_encode_plus(
            batch_text, 
            return_tensors="pt",
            padding=True,
            truncation=True
        )
        inputs = inputs.to(device)

        # Generate Summary
        summary_ids = model.generate(
            inputs["input_ids"],
            num_beams=num_beams,
            max_length=max_len,
            temperature=temperature,
            early_stopping=True
        )
        out = [
            tokenizer.decode(
                g, skip_special_tokens=True, clean_up_tokenization_spaces=False
            )
            for g in summary_ids
        ]

        batches[i] = out

    results = [summary for batch in batches for summary in batch]
    return results

batch_reqparser = reqparse.RequestParser()
batch_reqparser.add_argument("text", type=list, location="json", required=True)
batch_reqparser.add_argument("max_len", type=int, default=60, required=False)
batch_reqparser.add_argument("num_beams", type=int, default=4, required=False)
batch_reqparser.add_argument("temperature", type=float, default=1.0, required=False)
batch_reqparser.add_argument("model", default=config.transformers_models[0], required=False)

app = Flask(__name__)
api = Api(app)

class BatchSummarizer(Resource):
    def post(self):
        reqargs = batch_reqparser.parse_args()
        text = reqargs["text"]
        max_len = reqargs["max_len"]
        num_beams = reqargs["num_beams"]
        temperature = reqargs["temperature"]
        model = reqargs["model"]
        summaries = summarize(text, max_len, num_beams, temperature, config.batch_size, model)
        return summaries
     
api.add_resource(BatchSummarizer, "/batchsummarize")
app.run(debug=False, port=args.port, host="0.0.0.0", threaded=False)
