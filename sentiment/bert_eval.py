import torch
import requests
from transformers import AutoTokenizer, AutoConfig, BertForSequenceClassification
from torch.nn.functional import softmax
from typing import List

# global constants
MODEL_NAME = 'digitalepidemiologylab/covid-twitter-bert-v2'
tokenizer = AutoTokenizer.from_pretrained(MODEL_NAME)
mapping = { 0: 'negative', 1: 'neutral', 2: 'positive' }

class BertSentiment():
	"""
	Initializes a bert model used for evaluation
	@param path: local relative path of the bert model
	@param remote: defaults to empty, if specified will download model from url
	""" 
	def __init__(self, path: str, config: str, remote: str=""):
		if len(remote) != 0:
			self.download(remote)
		self.tokenizer = tokenizer
		self.load(path, config)
	
	"""
	Downloads bert model from remote
	@param remote: url location of bert model
	@param dest: destination path where model will be downloaded to
	"""
	def download(self, remote: str, dest: str) -> str:
		try:
			res = requests.get(remote, allow_redirects=True)
			with open(dest, "wb") as f:
				f.write(res.content)
			return dest
		except:
			print("Could not download model")
			return None

	"""
	Loads pytorch model in for inference
	@param path: local path to the bert model
        @param config: local path to bert config
	"""
	def load(self, path:str, config:str):
		self.device = torch.device('cuda:0') if torch.cuda.is_available() else torch.device('cpu')
		self.config = AutoConfig.from_pretrained(config)
		self.model = BertForSequenceClassification(self.config)
		self.model.load_state_dict(torch.load(path, self.device))
		self.model.to(self.device)
		self.model.eval()
	
	"""
	Takes in a tweet and calculates a sentiment prediction confidences
	"""
	def score(self, text):
		encodings = self.tokenizer(text, return_tensors="pt", padding=True, truncation=True, max_length=35)
		inputs = encodings["input_ids"].to(self.device)
		with torch.no_grad():
			logits = self.model(inputs, labels=None)[0]
		preds = softmax(logits.cpu(), dim=1)
		infer = torch.argmax(preds, dim=1)
		sentiment = [mapping[p.item()] for p in infer]
		infer = infer - 1
		return preds.tolist(), sentiment, infer.tolist()

