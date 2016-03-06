# InstantSlackBot
Simple, extensible, multithreaded Slack Bot Ruby framework

- **examples** - Example bots
- **instant_slack_bot** - InstantSlackBot module for painlessly writing multithreaded Slack Bots

InstantSlackBot is a simple to use Slack Bot Ruby framework with the following features:
- Multithreaded monitoring for fast responses
- Efficiently supports multiple bots per instance
- Bot conditions are based on Strings, Regexps or Procs
- Bot actions are based on Strings or Procs

InstantSlackBot can be run in as little as one line (well, one Ruby line).

```ruby
InstantSlackBot::Master.new(
  token: 'xoxp-XXXXXXXXXXX-XXXXXXXXXXX-XXXXXXXXXXX-XXXXXXXXXX', 
  bots: { conditions: 'hi', action: 'Hello!' }
).run
```
![alt text][one_line_slack]

[one_line_slack_pic]:https://raw.githubusercontent.com/robzr/instant-slack-bot/master/examples/pics/one_line_slack.png "Example output from one line bot"

