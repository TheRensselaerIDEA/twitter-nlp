def format_date_range(date_range):
    if not date_range:
        return ""
    date_range = tuple(d.strftime('%m/%d/%Y') for d in date_range)
    if len(date_range) == 1:
        return f"$\geq$ {date_range[0]}"
    if date_range[0] == date_range[1]:
        return date_range[0]
    return f"{date_range[0]} - {date_range[1]}"