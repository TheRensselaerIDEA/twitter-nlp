def get_tweet_text(hit):
    quoted_text = None
    if "quoted_status" in hit:
        quoted_status = hit["quoted_status"]
        quoted_text = quoted_status["extended_tweet"]["full_text"] if "extended_tweet" in quoted_status else quoted_status["text"]
    text = hit["extended_tweet"]["full_text"] if "extended_tweet" in hit else hit["text"]
    if quoted_text is not None:
        text = "[Quoted: \"{0}\"] {1}".format(quoted_text, text)
    return text

def get_tweet_location(hit):
    if "place" in hit and hit["place"] is not None:
        return ("{0}, {1}".format(hit["place"]["full_name"], hit["place"]["country"]), "Place")
    elif hit["user"]["location"] is not None:
        return (hit["user"]["location"], "User")
    else:
        return ("", "User")
    
def get_tweet_user(hit):
    return (hit["user"]["screen_name"], hit["user"]["verified"])