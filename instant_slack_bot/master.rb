#
# InstantSlackBot::Master
#
#   Master class - multiple Bots run in a single Master class
#
module InstantSlackBot
  require 'pp'
  require 'slack'
#  require 'slack-rtm-api'
  require 'thread'

  class Master
    # TODO: add default icon_url from github cdn
    DEFAULT_BOT_NAME = 'InstantSlackBot'
    DEFAULT_POST_OPTIONS = { icon_emoji: ':squirrel:', link_names: 'true', unfurl_links: 'false', parse: 'none' }
    THREAD_THROTTLE_DELAY = 0.001

    attr_accessor :post_options, :bots, :max_threads, :max_threads_per_bot

    def initialize(
      bots: nil,
      channels: nil,
      debug:false,
      max_threads: 50,
      max_threads_per_bot: 20,
      name: DEFAULT_BOT_NAME,
      post_options: {},
      token: nil
    )
      @bots = []
      @channel_criteria = channels
      @debug = debug
      @max_threads = max_threads
      @max_threads_per_bot = max_threads_per_bot
      @post_options = DEFAULT_POST_OPTIONS
      @post_options.merge!({ username: name }) if name
      @post_options.merge!(post_options)
      @token = token

      @slack = nil
      @slack_info = {}
      @threads = {}
      @users = {}
      @receive_message_queue = []

      connect_to_slack_webrpc
      connect_to_slack_rtm

      @slack_connection = @slack.auth.test.body
      raise "Error authenticating to Slack Web RPC" unless @slack_connection['ok']

      update_channels
      update_users
      add_bot bots
    end

    def connect_to_slack_webrpc
      @slack = Slack::RPC::Client.new(@token)
      auth_test = @slack.auth.test
    rescue StandardError => msg # TODO: Refine
      abort "Error Initializing Slack WebRPC: #{msg}"
    end

    def connect_to_slack_rtm
      @slack_rtm = SlackRTMApi::ApiClient.new(
        token: @token,
        debug: false)
      add_to_queue = proc do |message|
        # We could do more filtering here
        @receive_message_queue << message
      end
      @slack_rtm.bind(event_type: :message, event_handler: add_to_queue)
    rescue StandardError => msg # TODO: Refine
      abort "Error Initializing Slack RTM: #{msg}"
    end

    def name
      @post_options[:username]
    end

    def name=(name)
      @post_options[:username] = name
    end

    # TODO: should merge with RTM info
    def slack
      @slack_connection
    end

    def <<(arg)
      case arg.class.name
      when 'String', 'Regexp', 'Proc'
        add_channel arg
      when 'Array'
        arg.each { |arg| self << arg }
      when 'InstantSlackBot::Bot', 'Hash'
        add_bot arg
      else
        raise "Error trying to add class #{arg.class.name}"
      end
    end

    def channels=(arg)
      @channel_criteria = []
      case arg.class.name
      when 'Array'
        @channel_criteria += arg
      when 'String', 'Regexp', 'Proc'
        @channel_criteria << arg
      else
        raise "Channel (#{arg}) is an invalid class (#{arg.class.name})"
      end
      update_channels
    end

    def channels(query_type = :subscribed)
      if query_type == :available
        @slack.channels.list().body['channels'].map { |channel| channel['name'] }
      elsif query_type == :subscribed
        @channels.values.map { |ch| ch['name'] }
      else
        raise "InstantSlackBot#channels called with invalid argument #{all_or_available}"
      end
    end

    def users
      @users.values.map { |user| user['name'] }
    end

    # The actual event loop - does not return (yet). We should modify this to take
    #   an argument of how long to run, or try some thread coordination with the calling method
    #
    # TODO: improve error handling
    def run
      loop do
        if message = @receive_message_queue.shift then
          # First we process potential bot events
          if ['channel_join', 'channel_leave', 'user_change', 'team_join'].include? message['type']
            update_users
          elsif message['type'] =~ /^channel_(created|deleted|rename|archive|unarchive)$/
            update_channels
          end
          process_message(message: message)
        else
          sleep THREAD_THROTTLE_DELAY
        end
      end
    end

    private

    def add_channel(arg)
      @channel_criteria << arg
      update_channels
    end

    def add_bot(bot)
      case bot.class.name
      when 'Hash'
        @bots << InstantSlackBot::Bot.new(bot)
      when 'InstantSlackBot::Bot'
        @bots << bot if bot
      when 'Array'
        bot.each { |bot| add_bot bot }
      when 'NilClass'
      end
    end

    def update_channels
      @channels = {}
      channel_criteria = @channel_criteria 
      channel_criteria = [%r{.*}] unless channel_criteria && channel_criteria.length > 0
      begin
        @slack.channels.list.body['channels'].each do |channel|
          channel_criteria.each do |criteria|
            case criteria.class.name
            when "String"
              @channels[channel['id']] = channel if channel['name'].to_s == criteria
            when "Regexp"
              @channels[channel['id']] = channel if criteria.match(channel['name'].to_s)
            when "Proc"
              @channels[channel['id']] = channel if criteria.call(channel: channel['name'])
            else
              raise "Invalid channel type specified for channel #{cl_name}"
            end
          end
        end
      rescue StandardError => msg # TODO: Refine
        abort "Error: could not update channels (#{msg})"
      end
    end

    def update_users
      begin
        @slack.users.list.body['members'].each do |user|
          @users[user['id']] = user
        end
      rescue StandardError => msg # TODO: Refine
        abort "Error: could not update users (#{msg})"
      end
    end

    def process_message(message: message)
      return if message.key?('subtype') && message['subtype'] == 'bot_message'
      username = message['username']
      username ||= @users[message['user']]['name'] if @users[message['user']]
      channel = message['channel']
      @bots.each do |bot|
          # TODO: eliminate everything except message (?)
          #   offer a means to add user_typing
          bot_response = bot.try(
            text: message['text'], 
            user_name: username, 
            channel_name: @channels[channel]['name'], 
            message: message
          )
          if bot_response
            bot_response = { text: bot_response.to_s } unless bot_response.class.name == 'Hash'
            begin
              @slack.chat.postMessage @post_options.merge({ channel: channel }).merge(bot_response)
            rescue StandardError => msg # TODO: Refine
              abort "Error: could not postMessage: #{msg}"
            end
          end
      end
    end
  end
end
