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

* Create a **InstantSlackBot::Master** instance to communicate with the Slack API - it will need a Slack API token which
  [you can get here](https://api.slack.com/docs/oauth-test-tokens).
* Next, create at least one **InstantSlackBot::Bot**. A Bot needs two things to function.
  1. One or more **conditions** will determine when the Bot responds. A condition can be as
    simple as a text string or regular expression which is matched against each slack message.
     * Multiple conditions are be matched with boolean **and** or **or** behavior (the latter is the default).
     * Procs can be used for for more sophisticated conditions.
  * An **action** is needed, which determines the response when the condition(s) are met.
   The action can be as simple as a static text string to be displayed, or a Proc for more
   sophisticated responses.
* When using a Procs for conditions or actions, an optional hash argument will pass the message text, username and channel.
* Register each Bot with the Master instance using the << operator.
* Finally, call the Master#run method to begin operating your bot.

