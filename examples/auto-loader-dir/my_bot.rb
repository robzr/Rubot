require '../instant_slack_bot'

module MyBot
  class MyBot < InstantSlackBot::Bot

    @@options = { 
      debug: true
    }

    @@post_options = { 
      'username' => 'bubba',
      'icon_emoji' => ':smile:',
      'as_user' => false,
    }

    def conditions(message: nil)
      return true if message['text'] =~ /^hi /i
      return true if message['text'] =~ /instabot/i
      false
    end
  
    def action(message: nil)
      if message['username'] == 'paul'
        text = "ugh."
      elsif message['username'] == 'robzr'
        text = "Aww yah."
      else
        text = "Hello @#{message['username']}."
      end
      { 
        "attachments" => [
          {
            "fallback" => "Network traffic (kb/s): How does this look? @slack-ops - Sent by Julie Dodd - https://datadog.com/path/to/event",
            "title" => "Network traffic (kb/s)",
            "title_link" => "https://datadog.com/path/to/event",
            "text" => "How does this look? @slack-ops - Sent by Julie Dodd",
            "image_url" => "https://www.google.com/images/branding/googlelogo/1x/googlelogo_color_272x92dp.png",
            "color" => "#764FA5"
          }
        ]
      } 
#      { :text => 'hi' }
    end
  end
end

