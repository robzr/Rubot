# InstantSlackBot

InstantSlackBot is an easy to use Ruby framework for creating Slack Bots.
- Multithreaded channel monitoring for fast responses
- Supports multiple bots per instance
- Simple, intuitive and extensible Ruby syntax
- Bot conditions are based on Strings, Regexps or Procs
- Bot actions are based on Strings or Procs

InstantSlackBot can be run in as little as one line (well, one Ruby line):

```ruby
InstantSlackBot::Master.new(
  token: 'xoxp-XXXXXXXXXXX-XXXXXXXXXXX-XXXXXXXXXXX-XXXXXXXXXX', 
  bots: { conditions: 'hi', action: 'Hello!' }
).run
```
<img src="https://raw.githubusercontent.com/robzr/instant-slack-bot/master/examples/pics/one_line_slack.png" 
  alt="Example output from one line bot" height=98 width=252>

####How does it work?
* Create a **InstantSlackBot::Master** instance to communicate with the Slack API - it will need an API token which
  [you can get here](https://api.slack.com/docs/oauth-test-tokens).
* Create at least one **InstantSlackBot::Bot**. A Bot needs a *condition* and an *action*.
* The **condition(s)** will determine when the Bot responds. A condition can be as simple as a text string or 
  regular expression which is matched against each message.
* Multiple conditions can matched with boolean **and** or **or** logic (the default).
* An **action** forms the response when the conditions are met. An action can be as simple as a text string, or a 
  Proc for more sophisticated behavior.
* When using a Procs for conditions or actions, an optional hash argument will pass the message text, username and channel.
* Register each Bot with the Master instance using the << operator, and then call **Master#run** to operate the Bots.
