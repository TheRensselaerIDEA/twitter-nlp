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
    allFoundTweetIds = set()
    for point in self.__data:
      source = point['_source']
      try:
        originalTweeterName = source['in_reply_to_status']['screen_name']
        originalTweetId = source['in_reply_to_status']['id_str']
      except:
        # print(source.keys())
        # print(source['quoted_status'].keys())
        originalTweeterName = source['quoted_status']['user']['screen_name']
        originalTweetId = source['quoted_status']['id_str']

      responseTweeterName = source['user']['screen_name']
      responseTweetId = source['id_str']
      '''
      * logic for getting overall number of tweets per user (screen name)
      '''      
      if originalTweetId not in allFoundTweetIds:
        if originalTweeterName not in allTweeterCounts.keys():
          allTweeterCounts[originalTweeterName] = 1
        else:
          allTweeterCounts[originalTweeterName] += 1
        # mark the original tweet as seen
        allFoundTweetIds.add(originalTweetId)
      
      if responseTweetId not in allFoundTweetIds:
        if responseTweeterName not in allTweeterCounts.keys():
          allTweeterCounts[responseTweeterName] = 1
        else:
          allTweeterCounts[responseTweeterName] += 1
        # mark the response tweet as seen
        allFoundTweetIds.add(responseTweetId)
      
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
    self.size = len(allFoundTweetIds)
    print("Number of unique tweets present in the dataset:", self.size)
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
    
  def getBarChart(self, data, title, ylabel='Number of Tweets', xLabel="Top 3 Screen Names"):
    data = data[:3]
    labels = [point[0] for point in data]
    yData = [point[1] for point in data]
    plt.bar(labels, yData)
    plt.title(title)
    plt.ylabel(ylabel)
    plt.xlabel(xLabel)
    # plt.legend(labels)
    plt.savefig(title+".png")

  def __getData(self, index):
    data = search(index, max_hits=None)
    print("number of data points collected:",len(data))
    return data


if __name__ == "__main__":
  dataViz = DatasetVisualizer("coronavirus-data-pubhealth-quotes")
  atc, otc, rtc, rc = dataViz.getDataAnalytics()
  topATC = dataViz.getTopStats(atc)
  topOTC = dataViz.getTopStats(otc)
  topRTC = dataViz.getTopStats(rtc)
  topRC = dataViz.getTopStats(rc)
  
  print("One To Many Ratio:", sum([value[1] for value in topRC]) / sum([value[1] for value in topOTC]))
  print("Top original tweet contributors:", [point[0] for point in topOTC])
  print("Top original tweet contributor's contribution:", sum([point[1] for point in topRC]))
  dataViz.getBarChart(topOTC, "Original Tweet Distribution")
  dataViz.getBarChart(topRC, "Reply Distribution", ylabel="Number of Replies Received")
