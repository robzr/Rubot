# InstantSlackBot
Simple, extensible, multithreaded Slack Bot Ruby API 
- Lightweight and mostly transparent layer on top of Slack APIs
- Simple, intuitive and familiar Ruby API
- Fully multithreaded for efficient and fast response
- Supports multiple bots per instance
- Bot conditions are based on Strings, Regexps, Procs or Methods
- Bot actions are based on Strings, Procs or Methods
- Uses the Slack RTM API to receive messages in realtime
- Uses the Slack Web RPC API to post and transfer metadata


<img src="https://raw.githubusercontent.com/robzr/instant-slack-bot/master/examples/pics/one_line_slack.png" 
  alt="Example output from one line bot" height=98 width=252>

InstantSlackBot can be created and run in as little as one line.
```ruby
InstantSlackBot::Master.new(token: token, bots: { conditions: 'hi', action: 'Hello!' }).run
```

By passing Procs or Methods for conditions and actions, more [sophisticated bots can easily be made](examples).

<img src="https://raw.githubusercontent.com/robzr/instant-slack-bot/master/examples/pics/weather_bot_slack.png"
  alt="Example output from WeatherBot" height=542 width=815>

####How does it work?
* Create a **InstantSlackBot::Master** instance to communicate with the Slack API - you can 
[get an API token here](https://api.slack.com/docs/oauth-test-tokens).
* Create at least one **InstantSlackBot::Bot**. Each Bot needs at least one condition and an action.
* **conditions** determine when the Bot responds and can be as simple as a text string or 
  regular expression which is matched against each message, or Procs/Methods for more sophisticated logic.
* Multiple conditions can matched with boolean **and** or **or** logic (**or** is the default).
* An **action** forms the response when the conditions are met. An action can be as simple as a text string, but 
will usually be a Proc or Method.
* When using a Procs and Methods for conditions or actions, an optional hash argument will pass the received message and details
* Finally, register the Bots with the Master and call **Master#run** to begin operation.

####TODO
* Cache layer for bots - based on identical input, cache with time/hit count/size expire
* Write is_typing while waiting for bot to respond (will have to track)
* Update API documentation to RDoc standards
* Bundle and distribute on rubygems.org

###License & Credits
* The InstantSlackBot::SlackRTM class is based on [Rémi Delhaye's slack-rtm-api gem](https://github.com/rdlh/slack-rtm-api)

```
The MIT License (MIT)

Copyright (c) 2016 Rob Zwissler

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
