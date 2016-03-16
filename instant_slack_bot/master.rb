# InstantSlackBot::Master - multiple Bots run in a single Master class

require 'pp'
require 'slack'
require 'thread'

module InstantSlackBot #:nodoc:
  class Master
    attr_accessor :bots, :options, :post_options, :slack
    attr_reader :slack_connection # may be unnecessary

    def initialize(
      bots: nil,
      channels: nil,
      options: {},
      post_options: {},
      token: nil
    )
      @bots = {}
      @channel_criteria = channels || {}
      @options = DEFAULT_MASTER_OPTIONS.merge(options)
      @post_options = DEFAULT_MASTER_POST_OPTIONS.merge(post_options)
      @token = token

      @channels = {}
      @post_queue = Queue.new
      @post_queue_thread = nil
      @slack = nil
      @slack_rtm = nil
      @threads = {}
      @users = {}

      connect_to_slack_webrpc
      @slack_connection = @slack.auth.test.body
      raise "Error authenticating to Slack WebRPC" unless @slack_connection['ok']
      @post_options['username'] ||= @slack_connection['user']

      update_channels
      update_users
      launch_post_queue_thread
      add_bot bots
      connect_to_slack_rtm
    end

    def <<(arg)
      case arg.class.name
      when 'String', 'Regexp', 'Proc'
        add_channel arg
      when 'Array'
        arg.each { |arg| self << arg }
      when 'Hash'
        add_bot arg
      else
        if [arg.class.name, arg.class.superclass.name].include?(
          'InstantSlackBot::Bot'
        )
          add_bot arg
        else
          raise "Master#<< invalid class (#{arg.class.name})"
        end
      end
    end

    def connect_to_slack_rtm
      @slack_rtm = InstantSlackBot::SlackRTM.new(
        token: @token,
        debug: options[:debug]
      )
    end

    def connect_to_slack_webrpc
      @slack = Slack::RPC::Client.new(@token)
      auth_test = @slack.auth.test
    rescue StandardError => msg
      raise "Error Initializing Slack WebRPC: #{msg}"
    end

    def channels=(arg)
      @channel_criteria.clear
      case arg.class.name
      when 'Array'
        @channel_criteria += arg
      when 'String', 'Regexp', 'Proc'
        @channel_criteria << arg
      else
        raise "Master#channel=(#{arg}) invalid class (#{arg.class.name})"
      end
      update_channels
    end

    def channels(query_type = :subscribed)
      if query_type == :available
        @slack.channels.list().body['channels'].map { |channel| channel['name'] }
      elsif query_type == :subscribed
        @channels.values.map { |ch| ch['name'] }
      end
    end

    def delete(bot_id)
      return nil unless @bots.key? bot_id
      @threads[bot_id].each { |thread| thread.kill }
      @threads.delete(bot_id)
      @bots.delete(bot_id)
      true
    end

    # Event loop - does not return (yet).
    def run
      loop do
        if (thread_count + @bots.length) < options[:max_threads] && @slack_rtm.length > 0
          message = @slack_rtm.shift
          update_users if MESSAGE_TYPES_UPDATE_USERS.include? message['type']
          update_channels if MESSAGE_TYPES_UPDATE_CHANNELS.include? message['type']
          process_message(message: message) unless filter_message(message: message)
        end
        compact_bot_threads!
        sleep THREAD_THROTTLE_DELAY # some math here would be better
      end
    end

    def users
      @users.values.map { |user| user['name'] }
    end

    private

    def add_bot(bot)
      case bot.class.name
      when 'NilClass'
      when 'Hash'
        add_bot InstantSlackBot::Bot.new(bot)
      when 'Array'
        bot.each { |bot| add_bot bot }
      else
        if [bot.class.name, bot.class.superclass.name].include?(
          'InstantSlackBot::Bot'
        )
          @bots[bot.id] = bot
          @threads[bot.id] = []
          bot.master = self
        end
      end
    end

    def add_channel(arg)
      @channel_criteria << arg
      update_channels
    end

    def compact_bot_threads!
      @threads.each_value do |thread_array|
        thread_array.each do |thread|
          unless thread.status
            thread.join
            thread = nil
          end
        end
        thread_array.compact!
      end
    end

    def filter_message(message: nil)
      return true if message['type'] != 'message'
      return true if message.key?('subtype') && message['subtype'] == 'bot_message'
      false
    end

    def launch_post_queue_thread
      @post_queue_thread = Thread.new do
        loop do
          begin
            @slack.chat.postMessage @post_queue.shift
          rescue StandardError => msg
            puts "Master#launch_post_queue_thread error posting message: #{msg}"
          end
        end
      end
    end

    def message_plus(message: message)
      message.merge({ 
        'channelname' => resolve_channelname(message),
        'username' => resolve_username(message) 
      })
    end

    def post_message(message: nil, use_api: :webrpc)
      if use_api == :rtm
        puts "Master#post_message :rtm => #{message}" if options[:debug]
        @slack_rtm.send message
      else
        puts "Master#post_message :use_api => #{message}" if options[:debug]
        @post_queue << message
      end
    rescue StandardError => msg
      abort "Master#post_message error: #{msg}"
    end

    # This should be migrated to use a Queue and a message sending thread
    def process_message(message: nil)
      @bots.each do |bot_id, bot| 
        @threads[bot_id] << Thread.new do
          message_plussed = message_plus(message: message)
          if bot.conditions(master: self, message: message_plussed)
            set_user_typing(bot: bot, message: message) if bot.options[:use_api] == :rtm
            response = @post_options.merge(bot.post_options)
              .merge!({ 'type' => 'message', 'channel' => message['channel'] })
            action = bot.action(master: self, message: message_plussed)
            action = { text: action.to_s } if action.class.name != 'Hash'
            post_message(
              message: response.merge(action),
              use_api: bot.options[:use_api]
            )
          end
        end
      end
      true
    end

    def render_channel_criteria
      if @channel_criteria.length > 0
        @channel_criteria 
      else
        [%r{.*}]
      end
    end

    def resolve_channelname(message)
      if @channels.key?(message['channel'])
        @channels[message['channel'].to_s]['name']
      elsif message['channel'] =~ /^C0/
        'Group Message'
      elsif message['channel'] =~ /^D0/
        'Direct Message'
      else
        message['channel']
      end
    end

    def resolve_username(message)
      if @users.key?(message['user'].to_s)
        @users[message['user'].to_s]['name']
      else
        message['user']
      end
    end

    def set_user_typing(bot: nil, message: nil)
      # typing can be done every 3 seconds via a thread 
      message = bot.post_options.merge({
        'channel' => message['channel'],
        'type' => 'typing'
      })
      @slack_rtm.send message
    end

    def thread_count
      @threads.values.map { |thread_a| thread_a.length }.reduce(:+) || 0
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
    rescue StandardError => msg
      abort "Error: could not update channels (#{msg})"
    end

    def update_users
      @slack.users.list.body['members'].each do |user|
        @users[user['id']] = user
      end
    rescue StandardError => msg
      abort "Error: could not update users (#{msg})"
    end

  end
end
