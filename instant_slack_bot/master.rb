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
    DEFAULT_POST_OPTIONS = { icon_emoji: ':squirrel:', link_names: 'true', unfurl_links: 'true', parse: 'none' }
    THREAD_THROTTLE_DELAY = 0.01

    attr_accessor :post_options, :bots

    def initialize(
      bots: nil,
      channels: nil,
      debug:false,
      max_threads: 100,
      max_threads_per_channel: 5,
      name: DEFAULT_BOT_NAME,
      post_options: {},
      token: nil
    )
      @bots = []
      @channel_criteria = channels
      @debug = debug
      @max_threads = max_threads
      @max_threads_per_channel = max_threads_per_channel
      @post_options = DEFAULT_POST_OPTIONS
      @post_options.merge!({ username: name }) if name
      @post_options.merge!(post_options)
      @token = token

      @slack = nil
      @slack_info = {}
      @threads = {}
      @users = {}

    begin
      @slack = Slack::RPC::Client.new(@token)
      auth_test = @slack.auth.test
    rescue Exception => msg # TODO: Refine
      abort "Error Initializing InstantSlackBot: #{msg}"
    end

      @slack_connection = auth_test.body
      raise "Error authenticating to Slack" unless @slack_connection['ok']

      update_channels
      update_users
      add_bot bots
    end

    def name
      @post_options[:username]
    end

    def name=(name)
      @post_options[:username] = name
    end

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
      last_read_ts = {}
      @channels.each do |ch_id, ch_obj|
        last_read_ts[ch_id] = 0
        history = @slack.channels.history(channel: ch_id, count: 1)
        last_read_ts[ch_id] = defined?(history.body['messages'][0]['ts']) ? history.body['messages'][0]['ts'] : 0
      end
      mutex = Mutex.new
      loop do
        @channels.each do |ch_id, ch_obj|
          if @threads[ch_id].nil? || @threads[ch_id].length < @max_threads_per_channel
            @threads[ch_id] = [] unless @threads[ch_id]
            @threads[ch_id] << Thread.new {
              need_to_process = false
              history = nil
              process_message = nil
              mutex.synchronize do
                begin
                  slack_client = Slack::RPC::Client.new(@token)
                  history = slack_client.channels.history(channel: ch_id, oldest: last_read_ts[ch_id], count: 1000)
                  if defined?(history.body['messages']) && history.body['messages'] && history.body['messages'].length > 0
                    last_read_ts[ch_id] = history.body['messages'][0]['ts']
                    history.body['messages'].reverse_each do |message|
                      if message['type'] == 'message'
                        process_message = message
                        need_to_process = true
                      elsif ['channel_joined', 'channel_left', 'user_change', 'team_join'].include? message['type']
                        update_users
                      elsif message['type'] =~ /^channel_/
                        update_channels
                      else
                        # we'll need to handle other messages
                        puts "Master#run received message: #{message['type']}: #{message.pretty_inspect}" if @debug
                      end
                    end
                  end
                rescue Exception => msg # TODO: Refine
                  puts "Error: Exception #{msg} caught in be_a_bot"
                  need_to_process = false
                end
              end
              process_message(message: process_message, channel: ch_id) if need_to_process
            }
          end
        end
        # expire completed threads, compact the arrays
        @threads.each_key do |ch_id|
          @threads[ch_id].each_index do |tidx|
            if [nil, false].include? @threads[ch_id][tidx].status
              @threads[ch_id][tidx].join
              @threads[ch_id][tidx] = nil
            end
            @threads[ch_id].compact!
          end
        end
        sleep THREAD_THROTTLE_DELAY
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
      channel_criteria = [%r{.*}] unless channel_criteria.length > 0
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
      rescue Exception => msg # TODO: Refine
        abort "Error: could not update channels (#{msg})"
      end
    end

    def update_users
      begin
        @slack.users.list.body['members'].each do |user|
          @users[user['id']] = user
        end
      rescue Exception => msg # TODO: Refine
        abort "Error: could not update users (#{msg})"
      end
    end

    def process_message(message: message, channel: channel)
      user = message['username'] || @users[message['user']]['name'] 

      # TODO: better checking to make sure we do not respond to a bot
      if defined?(message['username']) && message['username'] != self.name()
        catch (:triggered) do
          @bots.each do |bot|
            bot_response = bot.check(text: message['text'], user: user, channel: @channels[channel]['name'])
            if bot_response
              bot_response = { text: bot_response.to_s } if bot_response.class.name != 'Hash'
              begin
                @slack.chat.postMessage @post_options.merge({ channel: channel }).merge(bot_response)
              rescue Exception => msg # TODO: Refine
                abort "Error: could not postMessage: #{msg}"
              end
              throw :triggered
            end
          end
        end
      end
    end
  end
end
