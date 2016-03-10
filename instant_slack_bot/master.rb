# InstantSlackBot::Master class - multiple Bots run in a single Master class

module InstantSlackBot
  require 'pp'
  require 'slack'
  require 'thread'

  class Master
    attr_accessor :bots, :options, :post_options

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
      @get_queue = Queue.new
      @post_queue = Queue.new
      @slack = nil
      @threads = {}
      @users = {}

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
    rescue StandardError => msg
      abort "Error Initializing Slack WebRPC: #{msg}"
    end

    def connect_to_slack_rtm
      @slack_rtm = InstantSlackBot::SlackRTM.new(
        token: @token,
        debug: options[:debug]
      )
      @slack_rtm.bind(event_type: :message, event_handler: proc { |msg| @get_queue << msg })
    rescue StandardError => msg
      abort "Error Initializing Slack RTM: #{msg}"
    end

    def slack
      # TODO: merge RTM connection info
      @slack_connection.merge({ })
    end

    def <<(arg)
      case arg.class.superclass.name || arg.class.name
      when 'String', 'Regexp', 'Proc'
        add_channel arg
      when 'Array'
        arg.each { |arg| self << arg }
      when 'InstantSlackBot::Bot', 'Hash'
        add_bot arg
      else
        raise "Master invalid class (#{arg.class.name})"
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

    def users
      @users.values.map { |user| user['name'] }
    end

    # Event loop - does not return (yet).
    def run
      loop do
        if thread_count < options[:max_threads] && message = @get_queue.shift
          update_users if MESSAGE_TYPES_UPDATE_USERS.include? message['type']
          update_channels if MESSAGE_TYPES_UPDATE_CHANNELS.include? message['type']
          process_message(message: message) unless filter_message(message: message)
	end
        compact_bot_threads!
        sleep THREAD_THROTTLE_DELAY # some math here would be better
      end
    end

    private

    def add_channel(arg)
      @channel_criteria << arg
      update_channels
    end

    def add_bot(bot)
      case bot.class.superclass.name || bot.class.name
      when 'InstantSlackBot::Bot'
        @bots[bot.id] = bot
        @threads[bot.id] = []
      when 'Hash'
        add_bot InstantSlackBot::Bot.new(bot)
      when 'Array'
        bot.each { |bot| add_bot bot }
      end
    end

    def compact_bot_threads!
      @threads.each_value do |t_array|
        t_array.each_index do |idx|
          if [nil, false].include? t_array[idx].status
            t_array[idx].join
            t_array[idx] = nil
          end
          t_array.compact!
        end
      end
    end

    def message_plus(message: message)
      message.merge({ 
        'channelname' => resolve_channelname(message),
        'username' => resolve_username(message) 
      })
    end

    def render_channel_criteria
      if @channel_criteria.length > 0
        @channel_criteria 
      else
        [%r{.*}]
      end
    end

    def resolve_username(message)
      if @users.key?(message['user'].to_s)
        @users[message['user'].to_s]['name']
      else
        message['user']
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

    def post_message(bot: nil, response: nil)
      return unless response
      response = { text: response.to_s } if response.class.name != 'Hash'
      if bot.options[:use_api] == :rtm
        @slack_rtm.send(
          @post_options.merge({ channel: message['channel'] })
          .merge(bot.options[:post_options])
          .merge(bot_response)
          .merge({ 'type' => 'message' })
        )
      elsif bot.options[:use_api] == :web_rpc
        @slack.chat.postMessage(
          @post_options.merge({ channel: message['channel'] })
          .merge(bot.options[:post_options])
          .merge(bot_response)
          .merge({ 'type' => 'message' })
        )
      end
    rescue StandardError => msg
      abort "Master#post_message error: #{msg}"
    end

    def set_user_typing(bot: nil, message: nil)
      # do we need as_user ?
      @slack_rtm.send({ 'channel' => message['channel'], 'type' => 'typing', 'as_user' => 'true' })
    end

    def filter_message(message: nil)
      return true if message.key?('subtype') && message['subtype'] == 'bot_message'
      return true if message['type'] != 'message'
      false
    end

    def process_message(message: nil)
      @bots.each do |bot_id, bot| 
        @threads[bot_id] << Thread.new {
          message_plussed = message_plus(message: message)
puts "bot.c"
pp bot.conditions(master: self, message: message_plussed)
          if bot.conditions(master: self, message: message_plussed)
#
# TODO: submit an is_typing method to API
# typing can be done every 3 seconds via a thread 
@slack.users.setActive({ })
@slack.users.setPresence({ 'presence' => 'auto' })
#
            post_message(
              bot: bot, 
              response: bot.action(master: self, message: message_plussed)
            )
          end
        }
      end
      true
    end

    def thread_count
      @threads.values.map { |thread_a| thread_a.length }.reduce(:+) || 0
    end

  end
end
