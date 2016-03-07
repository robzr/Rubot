# InstantSlackBot

Easy to use Ruby framework for creating Slack Bots featuring
- Lightweight and super fast layer on top of Slack APIs
- Fully multithreaded for efficient and fast response
- Supports multiple bots per instance
- Uses the RTM API to receive messages in realtime
- Uses Web RPC API to post and transfer metadata
- Simple, intuitive and extensible Ruby API
- Bot conditions are based on Strings, Regexps or Procs
- Bot actions are based on Strings or Procs


<img src="https://raw.githubusercontent.com/robzr/instant-slack-bot/master/examples/pics/one_line_slack.png" 
  alt="Example output from one line bot" height=98 width=252>

InstantSlackBot can be created in as little as one line (well, one Ruby line):
```ruby
InstantSlackBot::Master.new(
  token: 'xoxp-XXXXXXXXXXX-XXXXXXXXXXX-XXXXXXXXXXX-XXXXXXXXXX', 
  bots: { conditions: 'hi', action: 'Hello!' }
).run
```

Or by using Procs for conditions and actions, more [sophisticated bots can easily be made](examples).

<img src="https://raw.githubusercontent.com/robzr/instant-slack-bot/master/examples/pics/weather_bot_slack.png"
  alt="Example output from WeatherBot" height=542 width=815>

####How does it work?
* Create a **InstantSlackBot::Master** instance to communicate with the Slack API - you can 
[get an API token here](https://api.slack.com/docs/oauth-test-tokens).
* Create at least one **InstantSlackBot::Bot**. Each Bot needs at least one condition and an action.
* **conditions** determine when the Bot responds, can be as simple as a text string or 
  regular expression which is matched against each message, or a Proc for more sophisticated matching.
* Multiple conditions can matched with boolean **and** or **or** logic (**or** is the default).
* An **action** forms the response when the conditions are met. An action can be as simple as a text string, but 
will usually be a Proc.
* When using a Proc for conditions or actions, an optional hash argument will pass the message and details
* Finally, register the Bots with the Master and call **Master#run** to begin operation.

####TODO
* Cache layer for bots - based on identical input, cache with time/hit count/size expire
* Write is_typing while waiting for bot to respond (will have to track)
* Update API documentation to RDoc standards
* Bundle and distribute on rubygems.org
