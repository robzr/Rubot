#
# Autoloader test of Callback Class
#
require 'pp'
require 'uri'
require '../instant_slack_bot'

module CallbackBot
  class CallbackBot < InstantSlackBot::Bot

    OPTIONS = { debug: true } 

    POST_OPTIONS = { 
      'username' => 'CallbackBot',
      'icon_emoji' => ':smile:',
    }

    def initialize
      @callback = InstantSlackBot::Callback.new(options: OPTIONS)
      super(options: OPTIONS, post_options: POST_OPTIONS)
    end

    def conditions(message: nil)
      message['text'] =~ /^(cb|callback) /i ||
      message['text'] =~ /^google /i
    end
  
    def action(message: nil)
      case message['text']
      when/^google /
        "<#{google_callback message}|Google It Here>"
      else
        "<#{generic_callback message}|Callback test>"
      end
    end

    def google_callback(message)
      @callback.register lambda { |req,res|
        url = "http://lmgtfy.com/?q=" + URI.encode(
          message['text'].sub(/^google /, '')
        ).to_s
        reply_to(
          message: message,
          reply: "<#{url}|Redirecting...>"
        )
        res.set_redirect(WEBrick::HTTPStatus::TemporaryRedirect, url)
      }
    end

    def generic_callback(message)
      @callback.register lambda { |req,res|
        reply_to(
          message: message,
          reply: "Generic callback response to: #{message['text']}"
        )
        "Generic callback web response to: #{message['text']}"
      }
    end

  end
end
