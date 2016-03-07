#
# InstantSlackBot::Master
#
#   Master class - multiple Bots run in a single Master class
#
module InstantSlackBot
  require 'pp'
  require 'slack'
  require 'thread'

  class Master
    # TODO: add default icon_url from github cdn
    DEFAULT_BOT_NAME = 'InstantSlackBot'
    DEFAULT_POST_OPTIONS = { 
      icon_emoji: ':squirrel:', 
      link_names: 'true', 
      unfurl_links: 'false', 
      parse: 'none' 
    }
    THREAD_THROTTLE_DELAY = 0.001

    attr_accessor :post_options, :bots, :max_threads

    def initialize(
      bots: nil,
      channels: nil,
      debug:false,
      max_threads: 50,
      name: DEFAULT_BOT_NAME,
      post_options: {},
      token: nil
    )
      @bots = {}
      @channels = {}
      @channel_criteria = channels
      @debug = debug
      @max_threads = max_threads
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
      @slack_connection = @slack.auth.test.body
      raise "Error authenticating to Slack Web RPC" unless @slack_connection['ok']
      update_channels
      update_users
      add_bot bots
      connect_to_slack_rtm
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
      @channel_criteria.clear
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
    #   an argument of how long to run, or try some thread coordination with the
    #   calling method
    #
    # TODO: improve error handling
    def run
      loop do
        # change this to a do instaed of a shift, in case we can't do a thread, 
        #   we' won't shift it off
        if message = @receive_message_queue.shift then
          # First we process potential bot events
          if ['channel_join', 'channel_leave', 'user_change', 'team_join']
            .include? message['type']
            update_users
          elsif message['type'] =~ /^channel_(created|deleted|rename|archive|unarchive)$/
            update_channels
          end
          process_message(message: message) || @receive_message_queue.unshift(message)
          compact_bot_threads
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
      when 'InstantSlackBot::Bot'
        @bots[bot.id] = bot
        @threads[bot.id] = []
      when 'Hash'
        add_bot InstantSlackBot::Bot.new(bot)
      when 'Array'
        bot.each { |bot| add_bot bot }
      when 'NilClass'
      end
    end

    def compact_bot_threads
      @threads.each_key do |bot_id|
        @threads[bot_id].each_index do |tidx|
        if [nil, false].include? @threads[bot_id][tidx].status
          @threads[bot_id][tidx].join
          @threads[bot_id][tidx] = nil
        end
          @threads[bot_id].compact!
        end
      end
    end

    def message_plus(message: message)
      message.merge({ 
        'channelname' => message_resolve_channelname(message),
        'username' => message_resolve_username(message) 
      })
    end

    def message_resolve_username(message)
      if @users.key?(message['user'].to_s)
        @users[message['user'].to_s]['name']
      else
        message['user']
      end
    end

    def message_resolve_channelname(message)
      if @channels.key?(message['channel'])
        message['channel']
      elsif message['channel'] =~ /^D0/
        'Direct Message'
      else
        message['channel']
      end
    end

    def render_channel_criteria
      if @channel_criteria.length > 0
        @channel_criteria 
      else
        [%r{.*}]
      end
    end

    def update_channels
      @channels = {}
      @slack.channels.list.body['channels'].each do |channel|
        render_channel_criteria.each do |criteria|
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

    def update_users
      @slack.users.list.body['members'].each do |user|
        @users[user['id']] = user
      end
    rescue StandardError => msg # TODO: Refine
      abort "Error: could not update users (#{msg})"
    end

    def process_message(message: message)
      return true if message.key?('subtype') && message['subtype'] == 'bot_message'
      return true if message['type'] != 'message'
      if thread_count < @max_threads
        @bots.each do |bot_id, bot| 
          @threads[bot_id] << Thread.new {
            bot_response = bot.check(message: message_plus(message: message))
            begin
              if bot_response
                if bot_response.class.name != 'Hash'
                  bot_response = { text: bot_response.to_s }
                end
                @slack.chat.postMessage @post_options.merge({
                  channel: message['channel']
                }).merge(bot_response)
              end
            rescue StandardError => msg # TODO: Refine
              abort "process_message postMessage error: #{msg}"
            end
          }
        end
        true
      else
        false
      end
    end

    def thread_count
      @threads.values.map { |thread_a| thread_a.length }.reduce(:+)
    end
  end
end
