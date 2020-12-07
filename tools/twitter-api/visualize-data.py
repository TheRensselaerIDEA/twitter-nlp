import matplotlib as mpl
mpl.use('Agg')
from scrolling import search
import matplotlib.pyplot as plt

class DatasetVisualizer:
  def __init__(self, index):
    # self.tweeterCount = dict()
    self.index = index
    self.__data = self.__getData(self.index)
    self.size = None
    
  def getDataAnalytics(self):
    '''
    returns allTweeterCounts, originalTweeterCounts, responseTweeterCounts, replyCounts
    '''
    originalTweeterCounts = dict()
    responseTweeterCounts = dict()
    allTweeterCounts = dict()
    replyCounts = dict()
    originalTweetIds = set()
    responseTweetIds = set()
    allTweetIds = set()
    for point in self.__data:
      source = point['_source']
      originalTweeterName = source['in_reply_to_status']['screen_name']
      originalTweetId = source['in_reply_to_status']['id_str']
      responseTweeterName = responseTweeter = source['user']['screen_name']
      responseTweetId = point['_id']
      '''
      * logic for getting overall number of tweets per user (screen name)
      '''      
      if originalTweetId not in allTweetIds:
        if originalTweeterName not in allTweeterCounts.keys():
          allTweeterCounts[originalTweeterName] = 1
        else:
          allTweeterCounts[originalTweeterName] += 1
        # mark the original tweet as seen
        allTweetIds.add(originalTweetId)
      
      if responseTweetId not in allTweetIds:
        if responseTweeterName not in allTweeterCounts.keys():
          allTweeterCounts[responseTweeterName] = 1
        else:
          allTweeterCounts[responseTweeterName] += 1
        # mark the response tweet as seen
        allTweetIds.add(responseTweetId)
      
      '''
      * logic for getting number of tweets per user given that it was an original tweet
      * or given that it was a response tweet
      '''
      
      if originalTweetId not in originalTweetIds:
        # if this tweet has not already been seen increment the tweet count for the tweeter
        if originalTweeterName not in originalTweeterCounts.keys():
          originalTweeterCounts[originalTweeterName] = 1
        else:
          originalTweeterCounts[originalTweeterName] += 1
        # mark the original tweet id as seen
        originalTweetIds.add(originalTweetId)
      
      if responseTweetId not in responseTweetIds:
        if responseTweeterName not in responseTweeterCounts.keys():
          responseTweeterCounts[responseTweeterName] = 1
        else:
          responseTweeterCounts[responseTweeterName] += 1
        
        # logic for getting number of responses per tweeter 
        if originalTweeterName not in replyCounts.keys():
          replyCounts[originalTweeterName] = 1
        else:
          replyCounts[originalTweeterName] += 1
        
        # mark the response tweet as seen
        responseTweetIds.add(responseTweetId)
    self.size = len(allTweetIds)
        
    return allTweeterCounts, originalTweeterCounts, responseTweeterCounts, replyCounts
    
  def sortDictionary(self, dictionary, reverse=False):
    return {k: v for k, v in sorted(dictionary.items(), key=lambda item:item[1], reverse=reverse)}
    
  def getTopStats(self, dictionary, amount = 10):
    data = self.sortDictionary(dictionary, reverse=True)
    keys = list(data.keys())
    output = list()
    for key in keys[:amount]:
      output.append((key, dictionary[key]))
    return output
    
  def getPieChart(self, data, title, dataSize=None):
    if dataSize is None:
      if self.size is not None:
        dataSize = self.size
      else:
        print ("dataSize cannot be None")
        return False
    labels = [point[0] for point in data]
    # labels.append("Other")
    totalTopTweets = [point[1] for point in data]
    topTweetsSize = sum(totalTopTweets)
    sizes = [point[1]/topTweetsSize for point in data]
    # otherSize = (dataSize - sum([point[1] for point in data])) / dataSize
    # sizes.append(otherSize)
    print(sizes)
    fig1, ax1 = plt.subplots()
    ax1.pie(sizes, labels=labels, autopct='%1.1f%%',
        shadow=True, startangle=90, normalize=False)
    ax1.axis('image')  # Equal aspect ratio ensures that pie is drawn as a circle.
    plt.savefig(title + ".png")
    
    return True

  def __getData(self, index):
    data = search(index, max_hits=None)
    return data


if __name__ == "__main__":
  dataViz = DatasetVisualizer("coronavirus-data-pubhealth-quotes")
  atc, otc, rtc, rc = dataViz.getDataAnalytics()
  print(dataViz.getTopStats(atc))
  print(dataViz.getTopStats(otc))
  print(dataViz.getTopStats(rtc))
  print(dataViz.getTopStats(rc))
  
  dataViz.getPieChart(dataViz.getTopStats(atc), "tweetDistribution")
