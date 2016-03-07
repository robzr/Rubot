# InstantSlackBot
Simple, extensible, multithreaded Slack Bot Ruby API 
- Lightweight and minimal layer on top of Slack APIs
- Simple, intuitive and extensible Ruby API
- Fully multithreaded for efficient and fast response
- Supports multiple bots per instance
- Bot conditions are based on Strings, Regexps or Procs
- Bot actions are based on Strings or Procs
- Uses the RTM API to receive messages in realtime
- Uses Web RPC API to post and transfer metadata


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
* **conditions** determine when the Bot responds and can be as simple as a text string or 
  regular expression which is matched against each message, or a Proc for more sophisticated logic.
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

###License & Credits
* The SlackRTM class is based on [Rémi Delhaye's slack-rtm-api gem](https://github.com/rdlh/slack-rtm-api)

```
Copyright 2016 Rob Zwissler (rob@zwissler.org)
Distributed under the terms of the GNU Affero General Public License

instant-slack-bot is free software: you can redistribute it and/or modify it 
under the terms of the GNU Affero General Public License as published by the 
Free Software Foundation, either version 3 of the License, or (at your 
option) any later version.

instant-slack-bot is distributed in the hope that it will be useful, but 
WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY 
or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Affero General Public 
License for more details.

You should have received a copy of the GNU Affero General Public License
along with instant-slack-bot. If not, see <http://www.gnu.org/licenses/>.
```
