# InstantSlackBot

InstantSlackBot is a simple to use Ruby framework for creating Slack Bots.
- Multithreaded channel monitoring for fast response
- Supports multiple bots per instance for efficiency
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

##How does it work?

* First, create a InstantSlackBot::Master instance. This will be responsible for 
  communicating with the Slack API, so you'll have to give it a Slack API token which 
  [you can get here](https://api.slack.com/docs/oauth-test-tokens).
* Next, create at least one InstantSlackBot::Bot. A Bot needs two things to function:
  1. One or more **conditions** determine when the Bot responds. A condition can be as
    simple as a text string or regular expression which is matched against each message.
    * Multiple conditions can be matched with boolean **and** or **or** behavior.
    * Procs can be used for for more sophisticated conditions. An optional hash argument can 
      be used to parse the message text, username and channel where the message was posted.
  2. One **action** is needed, which determines the response when the condition(s) are met.
   The action can be as simple as a static text string to be displayed, or a Proc for more 
   sophisticated responses.
    * When using a Proc action, an optional hash argument can be used to parse the message 
     text, username and channel where it was posted to.
* The Bots need to be registered to the Master instance, using the << operator.
* Finally, call the Master#run method to begin operating your bot.
