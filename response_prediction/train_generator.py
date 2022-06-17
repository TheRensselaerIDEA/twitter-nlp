"""
Train a generator model
"""
import os
import argparse
import torch
import pandas as pd
import pickle
import pytorch_lightning as pl
from sklearn.model_selection import train_test_split
from torch.nn.utils.rnn import pad_sequence
from transformers import (
    AutoModelForCausalLM, 
    AutoTokenizer, 
    AdamW, 
    get_linear_schedule_with_warmup
)
from torch.utils.data import DataLoader, Dataset
from os import path

class GPT2FineTuner(pl.LightningModule):
    @staticmethod
    def add_model_specific_args(parent_parser):
        parser = parent_parser.add_argument_group("GPT2FineTuner")
        parser.add_argument("--dataset-file", default="tweet_response_training.csv", required=False, 
                            help="Path to the CSV file containing the training dataset. (default: %(default)s)")
        parser.add_argument("--base-modelpath", default="gpt2", required=False,
                            help="Base model to use for fine-tuning the generator. (default: %(default)s)")
        parser.add_argument("--max-sequence-length", type=int, default=512, required=False,
                            help="Maximum sequence length per training example (dialogue). (default: %(default)s)")
        parser.add_argument("--batch-size", type=int, default=4, required=False,
                            help="Physical batch size to use for each GPU. (default: %(default)s)")
        parser.add_argument("--learning-rate", type=float, default=5e-5, required=False,
                            help="Initial learning rate for the AdamW optimizer. (default: %(default)s)")
        parser.add_argument("--weight-decay", type=float, default=0.0, required=False,
                            help="Weight decay parameter for the AdamW optimizer. (default: %(default)s)")
        parser.add_argument("--adam-epsilon", type=float, default=1e-8, required=False,
                            help="Epsilon parameter for the AdamW optimizer. (default: %(default)s)")
        parser.add_argument("--warmup-steps", type=int, default=0, required=False,
                            help="Number of warmup steps on a linear schedule. (default: %(default)s)")
        parser.add_argument("--random-state", type=int, default=None, required=False,
                            help="Random seed for reproducibility. (default: %(default)s)")
        parser.add_argument("--overwrite-prepared-data", action="store_true", default=False, required=False, 
                            help="Re-tokenize dataset even if prepared training files exist. (default: %(default)s)")
        parser.add_argument("--val-split", type=float, default=0.1, required=False,
                            help=("Percentage of training set to hold out for validation. (default: %(default)s)"))
        return parent_parser
    
    def __init__(self, **kwargs):
        super().__init__()
        
        self.save_hyperparameters()
        
        self.tokenizer = AutoTokenizer.from_pretrained(self.hparams.base_modelpath)
        self.model = AutoModelForCausalLM.from_pretrained(self.hparams.base_modelpath)
        
        self.author_token = "<|author|>"
        self.message_token = "<|message|>"
        self.response_token = "<|response|>"
        self._add_special_tokens()
    
    def _add_special_tokens(self):
        """ Add special tokens to the tokenizer and the model if they have not already been added. """
        special_tokens = {"pad_token": "<|pad|>", "additional_special_tokens": [self.author_token, self.message_token, self.response_token]}
        num_added_tokens = self.tokenizer.add_special_tokens(special_tokens)
        if num_added_tokens > 0:
            print("Resizing token embeddings to add %d additional special tokens..." % num_added_tokens)
            self.model.resize_token_embeddings(len(self.tokenizer))
    
    def forward(self, **inputs):
        return self.model(**inputs)
    
    def _step(self, batch):
        outputs = self(**batch)
        loss = outputs[0]
        return loss
    
    def training_step(self, batch, batch_idx):
        loss = self._step(batch)
        self.log("train_loss", loss, on_step=True, on_epoch=False, prog_bar=False)
        return loss
    
    
    def validation_step(self, batch, batch_idx):
        loss = self._step(batch)
        perplexity = torch.exp(loss)
        self.log("val_loss", loss, on_step=False, on_epoch=True, prog_bar=True, sync_dist=True)
        self.log("val_perplexity", perplexity, on_step=False, on_epoch=True, prog_bar=False, sync_dist=True)
        return loss
    
    def configure_optimizers(self):
        no_decay = ["bias", "LayerNorm.weight"]
        optimizer_grouped_parameters = [
            {
                "params": [p for n, p in self.model.named_parameters() if not any(nd in n for nd in no_decay)],
                "weight_decay": self.hparams.weight_decay
            },
            {
                "params": [p for n, p in self.model.named_parameters() if any(nd in n for nd in no_decay)], 
                "weight_decay": 0.0
            }
        ]
        optimizer = AdamW(optimizer_grouped_parameters, lr=self.hparams.learning_rate, eps=self.hparams.adam_epsilon)
        #scheduler = get_linear_schedule_with_warmup(
        #    optimizer, num_warmup_steps=self.hparams.warmup_steps, num_training_steps=t_total
        #)
        return optimizer#, scheduler
    
    
    def prepare_data(self):
        dataset_dir = path.dirname(self.hparams.dataset_file)
        self.tokenized_train_filename = path.join(dataset_dir, "tokenized_train.pickle")
        self.tokenized_val_filename = path.join(dataset_dir, "tokenized_val.pickle")
        
        if self.hparams.overwrite_prepared_data or not path.exists(self.tokenized_train_filename):
            df = pd.read_csv(self.hparams.dataset_file)
            train_df, val_df = train_test_split(df, test_size=self.hparams.val_split, random_state=self.hparams.random_state)
            self.save_training_file(self.tokenized_train_filename, train_df)
            self.save_training_file(self.tokenized_val_filename, val_df)
            
    def save_training_file(self, filename, df):
        examples = []
        for _, row in df.iterrows():
            example = (f"{self.message_token}{row['message']}{self.author_token}{row['author']}"
                       f"{self.response_token}{row['response']}{self.tokenizer.eos_token}")
            examples.append(self.tokenizer.encode(example))
        with open(filename, "wb") as f:
            pickle.dump(examples, f, protocol=pickle.HIGHEST_PROTOCOL)
    
    def setup(self, stage=None):
        self.train_dataset = ResponseDataset(self.tokenizer, self.tokenized_train_filename, self.hparams.max_sequence_length)
        self.val_dataset = ResponseDataset(self.tokenizer, self.tokenized_val_filename, self.hparams.max_sequence_length)
    
    def collate(self, dialogs):
        pad_token_id = 0.0 if self.tokenizer._pad_token is None else self.tokenizer.pad_token_id
        input_ids = pad_sequence(dialogs, batch_first=True, padding_value=pad_token_id)
        attention_mask = torch.ones(input_ids.size(), dtype=input_ids.dtype)
        attention_mask[input_ids == pad_token_id] = 0
        
        return {"input_ids": input_ids, "labels": input_ids, "attention_mask": attention_mask}
    
    def train_dataloader(self):
        train_loader = DataLoader(self.train_dataset, batch_size=self.hparams.batch_size, collate_fn=self.collate)
        return train_loader
    
    def val_dataloader(self):
        val_loader = DataLoader(self.val_dataset, batch_size=self.hparams.batch_size, collate_fn=self.collate)
        return val_loader
        
class ResponseDataset(Dataset):
    def __init__(self, tokenizer, filename, max_sequence_length=None):
        #drop any examples which exceed the max sequence length (or the model max length as a default)
        if max_sequence_length is None or max_sequence_length > tokenizer.model_max_length:
            print("Using model max length %d as max sequence length" % tokenizer.model_max_length)
            max_sequence_length = tokenizer.model_max_length

        #open the dataset file
        with open(filename, "rb") as f:
            self.examples = pickle.load(f)
        
        num_loaded = len(self.examples)
        self.examples = [ex for ex in self.examples if len(ex) <= max_sequence_length]

        print("Loaded %d dialogs from dataset." % num_loaded)
        print("Dropped %d dialogs which exceed %d tokens. %d dialogs remain." % (
                    num_loaded - len(self.examples), 
                    max_sequence_length, 
                    len(self.examples)))

    def __len__(self):
        return len(self.examples)

    def __getitem__(self, item):
        return torch.tensor(self.examples[item], dtype=torch.long)
        
def main():
    # load the args & config
    parser = argparse.ArgumentParser("Train the generator model.")
    parser.add_argument("--early-stopping-patience", type=int, default=3, required=False,
                        help=("Number of validation epochs with no improvement in val_perplexity before stopping training. "
                              "(default: %(default)s)"))
    parser.add_argument("--checkpoint-save-top-k", type=int, default=-1, required=False,
                        help=("Number of checkpoints to save in ascending order of val_perplexity. Use -1 to save all "
                              "checkpoints. (default: %(default)s)"))
    parser.add_argument("--checkpoint-save-weights-only", action="store_true", default=False, required=False,
                        help=("Save only the model weights and not everything needed to resume training (optimizer state, etc.) "
                              "(default: %(default)s)"))
    
    parser = GPT2FineTuner.add_model_specific_args(parser)
    parser = pl.Trainer.add_argparse_args(parser)
    
    args = parser.parse_args()
    
    # Train the model
    gpt2_fine_tuner = GPT2FineTuner(**vars(args))
    
    early_stopping_callback = pl.callbacks.EarlyStopping(monitor='val_loss', patience=args.early_stopping_patience)
    checkpoint_callback = pl.callbacks.ModelCheckpoint(monitor="val_loss", save_top_k=args.checkpoint_save_top_k, 
                                                       save_weights_only=args.checkpoint_save_weights_only)
    
    trainer = pl.Trainer.from_argparse_args(args, callbacks=[early_stopping_callback, checkpoint_callback])
    trainer.fit(gpt2_fine_tuner)
    
    # Convert checkpoints to huggingface pretrained models
    print("Converting lightning checkpoints to HuggingFace pretrained models...")
    for ckpt_filepath, score in checkpoint_callback.best_k_models.items():
        ckpt_dir = path.dirname(ckpt_filepath)
        ckpt_name = path.splitext(path.basename(ckpt_filepath))[0]
        hf_savepath = path.join(ckpt_dir, ckpt_name)
        
        loaded_ckpt = GPT2FineTuner.load_from_checkpoint(ckpt_filepath)
        loaded_ckpt.model.save_pretrained(hf_savepath)
        loaded_ckpt.tokenizer.save_pretrained(hf_savepath)
        
        #if saving weights only, no need to hold on to the original lightning checkpoints.
        if args.checkpoint_save_weights_only:
            os.remove(ckpt_filepath)
            
    print("Done!")

if __name__ == "__main__":
    main()

