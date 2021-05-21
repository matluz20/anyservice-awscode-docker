import sys
import json
from datetime import datetime

events = sys.argv[1]

with open(events) as events:
  events = json.load(events)
  
  for event in events:
    date = datetime.fromtimestamp(event["timestamp"]/1000).strftime('%Y-%m-%d %H:%M:%S')
    message = event["message"]
    print(f"{date}  {message.rstrip()}")
