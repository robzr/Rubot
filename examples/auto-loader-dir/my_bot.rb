#
# Simple example bot loaded via AutoLoader. Edit in-place; it gets reloaded on saves.
#
require 'pp'
require '../instant_slack_bot'

module MyBot
  class MyBot < InstantSlackBot::Bot
    def initialize
      super(
        options: { debug: false },
        post_options: {
          'username' => 'MyBot',
          'icon_emoji' => ':smile:',
        }
      )
    end

    def conditions(message: nil)
      case message['text']
      when  /^hi /i, /instabot/i
        true
      when /type /i
        :typing
      else
        false
      end
    end
  
    def action(message: nil)
      case message['username']
      when 'paul'
        'Ugh, Paul again!?'
      when 'robzr'
        { text: "Hello, my Lord.", use_api: :rtm }
      else
        "Hi @#{message['username']}."
      end
    end
  end
end
