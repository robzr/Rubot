# InstantSlackBot

InstantSlackBot is a simple to use Slack Bot Ruby framework with the following features:
- Multithreaded channel monitoring for fast response
- Supports multiple bots per instance for efficiency
- Simple, intuitive and extensible Ruby syntax
- Bot conditions are based on Strings, Regexps or Procs
- Bot actions are based on Strings or Procs

InstantSlackBot can be run in as little as one line (well, one Ruby line).

```ruby
InstantSlackBot::Master.new(
  token: 'xoxp-XXXXXXXXXXX-XXXXXXXXXXX-XXXXXXXXXXX-XXXXXXXXXX', 
  bots: { conditions: 'hi', action: 'Hello!' }
).run
```
<img src="https://raw.githubusercontent.com/robzr/instant-slack-bot/master/examples/pics/one_line_slack.png" 
  alt="Example output from one line bot" height=98 width=252>

##How does it work?

* First, create an instance of the InstantSlackBot::Master class. The Master class
  is responsible for interacting with the Slack API, so you'll need to give it a
  Slack API token, that [you can get here](https://api.slack.com/docs/oauth-test-tokens).
* Now you'll have to create at least one InstantSlackBot::Bot.  A Bot needs two things
  to function.
** One or more *conditions* are needed in order for the Bot to know when to respond.  A
   condition can be a simple text string or a regular expression which is matched against
   every message posted.  A Proc can also be used for more sophisticated matching logic.
*** Conditions by default run with or boolean logic, meaning any one condition that is
    met will cause the action to run - however, using the logic: :and argument, the 
    behavior can be changed to require all conditions to be met.
*** When using a Proc condition, an optional hash argument is passed, which can be used
    to parse the message text, username and channel where it was posted to.
** One *action* is needed, which determines the response when the condition(s) are met.
   The action can be as simple as a static text string, or a Proc for more sophisticated
   responses.
*** When using a Proc action, an optional hash argument is passed, which can be used
    to parse the message text, username and channel where it was posted to.

