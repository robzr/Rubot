# InstantSlackBot
Simple, extensible, multithreaded Slack Bot Ruby API 
- Lightweight and largely transparent layer on top of Slack APIs
- Fully multithreaded for efficient and fast response
- Multiple bots can share a single API connection object
- Posting can be done via RTM API for low latency sending

###[InstantSlackBot Wiki](https://github.com/robzr/instant-slack-bot/wiki) features:
- [Design Goals](https://github.com/robzr/instant-slack-bot/wiki)
- [Architectural Overview](https://github.com/robzr/instant-slack-bot/wiki/Architecture)
- [Short Examples](https://github.com/robzr/instant-slack-bot/wiki/Short-Examples)
- [TODO List for upcoming features](https://github.com/robzr/instant-slack-bot/wiki/TODO)
- [License & Credits](https://github.com/robzr/instant-slack-bot/wiki)

####How does it work?
* Create a **InstantSlackBot::Master** instance to communicate with the Slack API - 
[get an API token here](https://api.slack.com/docs/oauth-test-tokens).
* Create at least one **InstantSlackBot::Bot**. Each Bot needs at least one condition and an action.
* **conditions** determine when the Bot responds and can be as simple as a text string or 
  regular expression which is matched against each message, or Procs/Methods/inherited Class for more sophisticated logic.
* Multiple conditions can matched with boolean **AND** or **OR** logic (**or** is the default).
* An **action** forms the response when the conditions are met. An action can be as simple as a text string, but 
will usually be a Proc/Lambda, Method or part of an inherited class.
* When using Procs/Lambdas or Methods for conditions or actions, a hash argument will pass the received message & more
* Full access to the Slack API is available to both actions and conditions
* For the most flexibility, inherit the Bot class and override the #conditions and #action methods (see [class-example](https://github.com/robzr/instant-slack-bot/blob/master/examples/class-bot)).
* Finally, register the Bots with the Master and call **Master#run** to begin operation.
