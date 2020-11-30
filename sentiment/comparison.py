import numpy as np
import pandas as pd
from vaderSentiment.vaderSentiment import SentimentIntensityAnalyzer
from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report

"""
This section grabs the SemEval dataset from Dropbox.
Requires a dropbox API key.
"""
import os.path
import dropbox

if not os.path.isfile('semeval.zip'):
  ACCESS_TOKEN = "dhmkFjUUQYAAAAAAAAAAAcRFqu7bkzhtbmjYLVZEbMg4wiyYtytDtXzXkShJT4Kc" 
  dbx = dropbox.Dropbox(ACCESS_TOKEN)
  with open("semeval.zip", "wb") as f:
      metadata, res = dbx.files_download(path="/2017_English_final.zip")
      f.write(res.content)

"""
This section processes the data files and loads the data into a dataframe
"""
# unzip data if folder is not present
if not os.path.isdir('semeval'):
  import zipfile
  with zipfile.ZipFile('semeval.zip', 'r') as zip_ref:
      zip_ref.extractall('semeval')

# get all folders with relavent data in them
task_folders = [f'semeval/2017_English_final/GOLD/{folder}'
                for folder in os.listdir('semeval/2017_English_final/GOLD') 
                if os.path.isdir(f'semeval/2017_English_final/GOLD/{folder}')
]

mapping = {'-2': 'negative', '-1': 'negative', '0': 'neutral', '1': 'positive', '2': 'positive'}

# create a generator for SemEval Twitter Data
# the data files are separated by tab and each folder has it's own data format
def parseTwitter(folders):
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

# create a pandas dataframe
df = pd.DataFrame(parseTwitter(task_folders), columns=['TweetId', 'Sentiment', 'Text'])

# f1 score and compute balanced accuracy
df.groupby(['Sentiment']).agg('count')

df.head()

"""
Clean up data and
Split the input into training set and test set
The data is split as follows
70 % training set, 15% test set, 15% validation set
"""
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

analyzer = SentimentIntensityAnalyzer()
predictions = []
for tweet in test_text:
    vs = analyzer.polarity_scores(tweet)['compound']
    if vs < -0.05:
        sentiment = 0
    elif vs > 0.05:
        sentiment = 2
    else:
        sentiment = 1
    predictions.append(sentiment)

predictions = np.array(predictions)
actual = test_labels.to_numpy()

# calculate accuracy
test_acc = np.sum(predictions == actual) / len(actual)
print("Accuracy: {0:.2f}".format(test_acc))

# plot confusion matrix
y_actu = pd.Series(actual, name='Actual')
y_pred = pd.Series(predictions, name='Predicted')
df_confusion = pd.crosstab(y_actu, y_pred)

print(df_confusion)


# plot metrics on the data
from sklearn.metrics import precision_recall_fscore_support as score
precision, recall, fscore, support = score(y_actu, y_pred)

print('precision: {}'.format(precision))
print('recall: {}'.format(recall))
print('fscore: {}'.format(fscore))
print('support: {}'.format(support))
 

