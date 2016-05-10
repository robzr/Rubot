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
      return true if message['text'] =~ /^hi /i
      return true if message['text'] =~ /instabot/i
      false
    end
  
    def action(message: nil)
      { 
        :text => 
          case message['username']
          when 'paul'
            'Ugh, Paul again!?'
          when 'robzr'
            'Hello, my lord.'
          else
            "Hi @#{message['username']}."
          end
      }
    end
  end
end
