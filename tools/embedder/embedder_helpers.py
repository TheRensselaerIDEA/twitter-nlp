def get_query():
    query = {
    "_source": [
        "text",
        "extended_tweet.full_text",
        "quoted_status.text",
        "quoted_status.extended_tweet.full_text"
    ],
    "query": {
        "bool": {
        "filter": [
            {
            "bool": {
                "must_not": {
                "exists": {
                    "field": "embedding.use_large"
                  }
                }
              }
            },
            {
            "bool": {
                "must_not": {
                "exists": {
                    "field": "retweeted_status.id"
                  }
                }
              }
            }
          ]
        }
      }
    }
    return query