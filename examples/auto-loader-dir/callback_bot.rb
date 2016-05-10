#
# Autoloader test of Callback Class
#
require 'pp'
require 'uri'
require '../instant_slack_bot'

module CallbackBot
  class CallbackBot < InstantSlackBot::Bot

    OPTIONS = { debug: false } 

    POST_OPTIONS = { 
      'username' => 'CallbackBot',
      'icon_emoji' => ':smile:',
    }

    def initialize
      @callback = InstantSlackBot::Callback.new(options: OPTIONS)
      super(options: OPTIONS, post_options: POST_OPTIONS)
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
        url = "http://lmgtfy.com/?q="
        url += URI.encode(message['text'].sub(/^google /, '')).to_s
        reply_to(message: message,
                 reply: "Initiating redirect to: #{url}")
        res.set_redirect(WEBrick::HTTPStatus::TemporaryRedirect, url)
      }
    end

    def generic_callback(message)
      @callback.register lambda { |req,res|
        reply_to(message: message,
                 reply: "Generic callback response to: #{message['text']}")
        "Generic callback web response to: #{message['text']}"
      }
    end

  end
end
