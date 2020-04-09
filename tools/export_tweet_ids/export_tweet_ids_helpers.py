from datetime import datetime

def get_query(mode, range_start, range_end):
    query = {
        "_source": False,
        "query": {
            "bool": {
                "filter": [
                    {
                        "range": {
                            "created_at": {
                            "format": "strict_date_hour_minute_second",
                            "gte": range_start.strftime("%Y-%m-%dT%H:%M:%S"),
                            "lt": range_end.strftime("%Y-%m-%dT%H:%M:%S"),
                            "time_zone": "+00:00"
                            }
                        }
                    }
                ]
            }
        },
        "sort": [
            { "created_at": "asc" },
            { "_id": "asc"}
        ]
    }
    if mode == "originals-only":
        query["query"]["bool"]["filter"].append({
            "bool": {
                "must_not": {
                    "exists": { 
                        "field": "retweeted_status.id" 
                    }
                }
            }
        })
    return query