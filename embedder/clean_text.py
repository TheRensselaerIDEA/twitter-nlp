import re

def clean_text(text, normalize_case=False, normalize_whitespace=True, remove_uris=True, blacklist_regex="non_alpha_numeric_punct"):
    """Clean text to prepare for training and inference.
    
    Args:
      text: the text to clean
    """
    if blacklist_regex is not None:
        if blacklist_regex == "non_alpha_numeric":
            blacklist_regex = r"[^a-zA-Z1-9 ]"
        elif blacklist_regex == "non_alpha_numeric_punct":
            blacklist_regex = r"[^a-zA-Z1-9 `~!@#$%^&*()-_=+\[\];:'\",./?’]"
    
    if normalize_case:
        text = text.lower()
    if normalize_whitespace:
        text = re.sub(r"[\s]+", " ", text)
    if remove_uris:
        text = re.sub(r"http\S+", "", text)
    if blacklist_regex is not None:
        text = re.sub(blacklist_regex, "", text)
    if normalize_whitespace:
        text = re.sub(r" +", " ", text)
        text = text.strip()
            
    return text