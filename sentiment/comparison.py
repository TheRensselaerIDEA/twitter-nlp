import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import argparse, os.path, requests, sys
import dropbox

from typing import List, IO
from vaderSentiment.vaderSentiment import SentimentIntensityAnalyzer
from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report
from sklearn.metrics import precision_recall_fscore_support as score
from config import Config

"""
This section grabs the SemEval dataset from Dropbox.
Requires a dropbox API key.
"""
def downloadDataset(fileurl: str, outpath: str='semeval.zip'):
    if '.zip' not in outpath:
        outpath = f'{outpath}.zip'

    if not os.path.isfile(outpath):
      res = requests.get(fileurl, allow_redirects=True)
      with open(outpath, "wb") as f:
          f.write(res.content)

"""
Create a generator for SemEval Twitter Data
The data files are separated by tab and each folder has it's own data format
"""
def parseTwitter(folders):
  mapping = {'-2': 'negative', '-1': 'negative', '0': 'neutral', '1': 'positive', '2': 'positive'}

  for folder in folders:
    for file in [f'{folder}/{f}' for f in os.listdir(folder) if 'twitter' in f]:
      with open(file, 'r') as f:
        for line in f:
          segments = line.rstrip().split('\t')
          if len(segments) < 3:
            continue
          elif 'A' in folder:
            tweet_data = [segments[0], segments[1], ''.join(segments[2:])]
          elif 'B' in folder:
            tweet_data = [segments[0], segments[-2], segments[-1]]
          else:
            tweet_data = [segments[0], mapping[segments[-2]], segments[-1]]
          yield tweet_data

"""
This section processes the data files and loads the data into a dataframe
"""
def loadData(datapath: str='semeval'):
    # unzip data if folder is not present
    if not os.path.isdir(datapath):
      import zipfile
      with zipfile.ZipFile(f'{datapath}.zip', 'r') as zip_ref:
          zip_ref.extractall(datapath)

    # get all folders with relavent data in them
    task_folders = [f'{datapath}/2017_English_final/GOLD/{folder}'
                    for folder in os.listdir(f'{datapath}/2017_English_final/GOLD') 
                    if os.path.isdir(f'{datapath}/2017_English_final/GOLD/{folder}')
    ]

    # create a pandas dataframe
    return pd.DataFrame(parseTwitter(task_folders), columns=['TweetId', 'Sentiment', 'Text'])

"""
Clean up data and
Split the input into training set and test set
The data is split as follows
70 % training set, 15% test set, 15% validation set
"""
def runTests(df, thresholds: List[float], outfile: IO, outgraph: str):
    # eliminate off topic tweets and make categorical
    df = df[df.Sentiment != 'off topic']
    df.Sentiment = pd.Categorical(df.Sentiment)
    df.Sentiment = df.Sentiment.map({'negative': 0, 'neutral': 1, 'positive':2})

    train_text, temp_text, train_labels, temp_labels = train_test_split(df['Text'], df['Sentiment'], 
                                                                        random_state=2018, 
                                                                        test_size=0.3, 
                                                                        stratify=df['Sentiment'])

    val_text, test_text, val_labels, test_labels = train_test_split(temp_text, temp_labels, 
                                                                    random_state=2018, 
                                                                    test_size=0.5, 
                                                                    stratify=temp_labels)
    actual = test_labels.to_numpy()
    accuracies = []
    for threshold in thresholds:
        print(f'Threshold: {threshold}', file=outfile)
        predictions = classify(test_text, threshold)

        # calculate accuracy
        test_acc = np.sum(predictions == actual) / len(actual)
        accuracies.append(test_acc)
        print(f'Accuracy: {test_acc:.2f}', file=outfile)

        # plot confusion matrix
        y_actu = pd.Series(actual, name='Actual')
        y_pred = pd.Series(predictions, name='Predicted')
        df_confusion = pd.crosstab(y_actu, y_pred)

        print(df_confusion, file=outfile)


        # plot metrics on the data
        precision, recall, fscore, support = score(y_actu, y_pred)

        print(f'precision: {precision}', file=outfile)
        print(f'recall:    {recall}', file=outfile)
        print(f'fscore:    {fscore}', file=outfile)
        print(f'support:   {support}', file=outfile)
        print(file=outfile)
        
    # plot the accuracy results
    fig = plt.figure()
    plt.plot(thresholds, accuracies, 'b.-')
    fig.suptitle('Vader accuracy per threshold', fontsize=20)
    plt.xlabel('Threshold percentage %', fontsize=16)
    plt.ylabel('Accuracy %', fontsize=16)
    fig.savefig(outgraph)
    
"""
Performs the the classification based on a specific threshold
"""
def classify(test_text, threshold: float=0.05):
    analyzer = SentimentIntensityAnalyzer()
    predictions = []
    for tweet in test_text:
        vs = analyzer.polarity_scores(tweet)['compound']
        if vs < -1 * threshold:
            sentiment = 0
        elif vs > threshold:
            sentiment = 2
        else:
            sentiment = 1
        predictions.append(sentiment)
    return np.array(predictions)

if __name__ == "__main__":
    parser = argparse.ArgumentParser("Analysis tool for evaluting performance of Vader on SemEval")
    parser.add_argument("--configfile", "-c", default="config.json", required=False, help="Path to the config file to use.")
    parser.add_argument("--outfile", "-o", default=None, required=False, help="Path to the print the results.") 
    parser.add_argument('--outgraph', '-g', default="results.png", required=False, help="Path to the print the results graph.")
    parser.add_argument('--thresholds', '-t', nargs='+', default=None, required=False, help='The thresholds that need to be tested')
    args = parser.parse_args()
    config = Config.load(args.configfile)
    outfile = sys.stdout if args.outfile is None else open(args.outfile, 'w')
    thresholds = config.thresholds if args.thresholds is None else args.thresholds
    thresholds = [float(t) for t in thresholds]
    
    print('Downloading dataset...', file=sys.stderr)
    downloadDataset(config.semeval_url, config.semeval_dataset)

    print('Loading dataset...', file=sys.stderr)
    df = loadData(config.semeval_dataset)

    print('Evaluating tests...', file=sys.stderr)
    runTests(df, thresholds, outfile, args.outgraph)

    print('Done', file=sys.stderr)
    outfile.close()

