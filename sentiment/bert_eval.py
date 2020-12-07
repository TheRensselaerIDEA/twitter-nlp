import torch
import requests
from transformers import AutoTokenizer
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
	def __init__(self, path: str, remote: str=""):
		if len(remote) != 0:
			self.download(remote)
		self.tokenizer = tokenizer
		self.load(path)
	
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
	@patam path: local path to the bert model
	"""
	def load(self, path:str):
		self.device = torch.device('cuda') if torch.cuda.is_available() else torch.device('cpu')
		self.model = torch.load(path)
		self.model.to(self.device)
		self.model.eval()
	
	"""
	Takes in a tweet and calculates a sentiment prediction confidences
	"""
	def score(self, text):
		encoding = self.tokenizer(text, return_tensors="pt", padding=True, truncation=True, max_length=35)
		inputs = encoding["input_ids"].to(self.device)
		logits = self.model(inputs, labels=None)[0]
		temp = torch.flatten(logits.cpu())
		preds = softmax(temp, dim=0)
		sentiment = mapping[torch.argmax(preds).item()]
		return preds.tolist(), sentiment

