#
# Autoloader test of Callbacks
#
require 'pp'
require 'uri'
require '../instant_slack_bot'

module UseCallbacks
  class CallBackBot < InstantSlackBot::Bot

    def initialize
      @callback = InstantSlackBot::Callback.new
      super(options: { debug: true},
            post_options: {
              'username' => 'bubbaBot',
              'icon_emoji' => ':smile:',
            })
    end

    def conditions(message: nil)
      return true if message['text'] =~ /^(cb|callback) /i
      return true if message['text'] =~ /^google /i
      false
    end
  
    def action(message: nil)
      if message['text'] =~ /^google /
        "<#{google_callback message}|Google It Here>"
      else
        "<#{generic_callback message}|Callback test>"
      end
    end

    def google_callback(message)
      @callback.register lambda { |req,res|
        url = 'http://lmgtfy.com/?q=' + 
          URI.encode(message['text'].sub(/^google /, ''))
        puts "Redirecting to: #{url}"
        res.set_redirect(WEBrick::HTTPStatus::TemporaryRedirect, url)
      }
    end

    def generic_callback(message)
      @callback.register lambda { |req,res|
        reply_to(
          message: message,
          reply: "Callback message response to: #{message['text']}"
        )
        "Callback web response to: #{message['text']}"
      }
    end

  end
end
