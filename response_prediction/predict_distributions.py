from flask import Flask
from flask_restful import Resource, Api, reqparse
from config import Config
from transformers import AutoModelForCausalLM, AutoModelForSequenceClassification, AutoTokenizer
from transformers.trainer_utils import set_seed
from sentence_transformers import SentenceTransformer
from clean_text import clean_text
import torch
import tensorflow_hub as hub
import argparse
import numpy as np
import math

def start():
    parser = argparse.ArgumentParser("Run the response prediction service")
    parser.add_argument("--configfile", "-c", default="config.json", required=False, help="Path to the config file to use.")
    parser.add_argument("--port", "-p", default="8080", required=False, type=int, help="Port to run server on.")
    args = parser.parse_args()

    print()
    print("Running with arguments:")
    print(args)
    print()

    config = Config.load(args.configfile)
    
    #load generator model
    tokenizer = AutoTokenizer.from_pretrained(config.model_path)
    model = AutoModelForCausalLM.from_pretrained(config.model_path)
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    print(device)
    model.to(device)

    #load sentiment model
    sentiment_tokenizer = AutoTokenizer.from_pretrained(config.sentiment_modelpath)
    sentiment_model = AutoModelForSequenceClassification.from_pretrained(config.sentiment_modelpath)
    sentiment_model.to(device)

    #load embedding model
    if config.embed_enabled:
        if config.embedding_type == "use_large":
            use_large = hub.load(config.use_large_tfhub_url)
        else:
            sbert = SentenceTransformer(config.sbert_model_name)
            sbert.max_seq_length = config.sbert_max_seq_length
    
    def get_sentiment(responses, config):
        n_batches = math.ceil(len(responses) / config.sentiment_batch_size)
        batches = [None] * n_batches
        for i in range(n_batches):
            start = i * config.sentiment_batch_size
            end = start + config.sentiment_batch_size   
            batch_inputs = sentiment_tokenizer(responses[start:end], 
                                                padding=True, 
                                                truncation=True, 
                                                return_tensors="pt", 
                                                max_length=config.sentiment_max_seq_length)
            batch_inputs = batch_inputs.to(device)
            
            class_weights = torch.tensor([-1., 0., 1.]).to(device)
            
            with torch.no_grad():
                logits = sentiment_model(**batch_inputs).logits
                probs = torch.nn.functional.softmax(logits, dim=-1)
                #Convert polarity classes (negative, positive) to score in (-1, 1)
                polarity_scores = torch.matmul(probs, class_weights)
                
            batches[i] = polarity_scores.to("cpu").numpy()
        
        scores = np.concatenate(batches, axis=0)
            
        return scores

    def sample_responses(prompts, sample_size, num_beams, temperature, random_state, config):
        if random_state:
            set_seed(random_state)
        author_token, message_token, response_token = tokenizer.additional_special_tokens

        prompts = [f"{message_token}{p['message']}{author_token}{p['author']}{response_token}" 
                   for p in prompts]
        
        #Generate sample_size response samples for each prompt in the set
        results = []
        n_batches = math.ceil(len(prompts) / config.generate_batch_size)
        for s in range(sample_size):
            batches = [None] * n_batches
            for i in range(n_batches):
                start = i * config.generate_batch_size
                end = start + config.generate_batch_size
            
                batch_text = prompts[start:end]
                inputs = tokenizer(batch_text, return_tensors='pt', padding=True)
                inputs = inputs.to(device)
                
                response_ids = model.generate(inputs.input_ids, 
                                                attention_mask=inputs.attention_mask,
                                                max_length=tokenizer.model_max_length,
                                                pad_token_id=tokenizer.pad_token_id,
                                                #no_repeat_ngram_size=3,
                                                #length_penalty=0.8,
                                                top_k=50,
                                                top_p=0.95,
                                                do_sample=True,
                                                temperature=temperature,
                                                num_beams=num_beams,
                                                early_stopping=True,
                                                num_return_sequences=1)
               
                batches[i] = [tokenizer.decode(g[inputs.input_ids.shape[-1]:], skip_special_tokens=True) for g in response_ids]
                
            sample_results = [response for batch in batches for response in batch]
            results.extend(sample_results)
        results = np.array(results)
        
        if config.embed_enabled:
            cleaned_results_for_embedding = [clean_text(r) for r in results]
            if config.embedding_type == "use_large":
                n_batches = math.ceil(len(results) / config.embed_batch_size)
                batches = [None] * n_batches
                for i in range(n_batches):
                    start = i * config.embed_batch_size
                    end = start + config.embed_batch_size
                    batch_vecs = np.array(use_large([t for t in cleaned_results_for_embedding[start:end]]))
                    batches[i] = batch_vecs
                
                vecs = np.concatenate(batches, axis=0)
            else:
                vecs = sbert.encode(cleaned_results_for_embedding, batch_size=config.embed_batch_size, normalize_embeddings=True)
        
        cleaned_results_for_sentiment = [clean_text(r, blacklist_regex=None) for r in results]
        sentiments = get_sentiment(cleaned_results_for_sentiment, config)

        results_rollup = []
        n_prompts = len(prompts)
        for i in range(n_prompts):
            sample_selector = np.zeros(len(results), dtype=bool)
            for s in range(sample_size):
                sample_selector[i+n_prompts*s] = True
            if config.embed_enabled:
                results_rollup.append((results[sample_selector].tolist(), vecs[sample_selector].tolist(), sentiments[sample_selector].tolist()))
            else:
                results_rollup.append((results[sample_selector].tolist(), [], sentiments[sample_selector].tolist()))
            
        return results_rollup
    
    batch_reqparser = reqparse.RequestParser()
    batch_reqparser.add_argument("prompts", type=list, location="json", required=True)
    batch_reqparser.add_argument("sample_size", type=int, default=5, required=False)
    batch_reqparser.add_argument("num_beams", type=int, default=3, required=False)
    batch_reqparser.add_argument("temperature", type=float, default=1.5, required=False)
    batch_reqparser.add_argument("random_state", type=int, default=None, required=False)
    
    app = Flask(__name__)
    api = Api(app)
    
    class BatchResponseSampler(Resource):
        def post(self):
            reqargs = batch_reqparser.parse_args()
            prompts = reqargs["prompts"]
            sample_size = reqargs["sample_size"]
            num_beams = reqargs["num_beams"]
            temperature = reqargs["temperature"]
            random_state = reqargs["random_state"]
            results = sample_responses(prompts, sample_size, num_beams, temperature, random_state, config)
            return results
        
    api.add_resource(BatchResponseSampler, "/batchsampleresponses")
    app.run(debug=False, port=args.port, host="0.0.0.0", threaded=False)
    
if __name__ == "__main__":
    start()
