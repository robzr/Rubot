require '../instant_slack_bot'

module MyBot

  class MyBot < InstantSlackBot::Bot
    def conditions(arg)
      message = arg[:message]
      return true if message['text'] =~ /^hi /
      false
    end
  
    def action(arg)
      message = arg[:message]
      "bobo @#{message['username']}"
    end
  end

end

