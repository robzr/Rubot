#
# Slabot:: Small and simple to use multi-threaded Slack bot API -- @robzr
#
# Depends on slack-ruby: sudo gem install slack-ruby
#
module Slabot
  require 'pp'
  require 'slack'
  require 'thread'

  # A Trigger is a list of conditions and a callback proc, which is called when
  #   a condition is met, using :or or :and boolean logic.  Conditions can be 
  #   strings, regex's, or procs. Return value of the callback proc is a string 
  #   literal which is posted to Slack.
  #
  class Trigger
    attr_accessor :callback, :condition_logic, :debug
    attr_reader :conditions

    def initialize(callback: nil, conditions: nil, condition_logic: :or, debug: false)
      @condition_logic = condition_logic

      self.callback = callback
      self.conditions = conditions
    end

    def callback=(arg)
      case arg.class.name
      when 'Proc'
        @callback = arg
      when 'String'
        @callback = proc { arg }
      end
    end

    def conditions=(arg)
      @conditions = []
      case arg.class.name
      when 'Array'
        @conditions += arg
      when 'String', 'Regexp', 'Proc'
        @conditions << arg
      else
        raise "Condition (#{arg}) is an invalid class (#{arg.class.name})"
      end
    end

    def <<(arg)
      @conditions << arg
    end

    # TODO: change arg type to a single hash for brevity
    def check(args)
      run_callback = false
      case @condition_logic
      when :or
        @conditions.each { |condition| run_callback ||= check_condition args.merge({ condition: condition }) }
      when :and
        run_callback = true
        @conditions.each { |condition| run_callback &&= check_condition args.merge({ condition: condition }) }
      end
      @callback.call(args) if run_callback
    end

    def check_condition(condition: condition, text: nil, user: nil, channel: nil)
      case condition.class.name
      when 'String'
        run_callback = true if /\b#{condition}\b/i.match(text)
      when 'Regexp'
        run_callback = true if condition.match(text)
      when 'Proc'
        run_callback = true if condition.call(text: text, user: user, channel: channel)
      else
        raise "Condition (#{condition}) is an invalid class (#{condition.class.name})"
      end
    end
  end

  class Slabot
    # TODO: add default icon_url from github cdn
    DEFAULT_POST_OPTIONS = { username: 'Slabot', icon_emoji: ':squirrel:', link_names: 'true', unfurl_links: 'false', parse: 'none' }
    THREAD_THROTTLE_DELAY = 0.01

    attr_accessor :post_options, :triggers

    def initialize(
      bot_name: nil,
      slack_token: nil,
      icon_url: '',
      max_threads: 100,
      max_threads_per_channel: 5,
      post_options: {},
      channels: nil,
      trigger: nil,
      debug:false)

      @slack_token = slack_token
      @max_threads = max_threads
      @max_threads_per_channel = max_threads_per_channel
      @post_options = DEFAULT_POST_OPTIONS
      @post_options.merge!({ username: bot_name }) if bot_name
      @post_options.merge!(post_options)
      @channel_criteria = channels
      @debug = debug
      @triggers = []
      @threads = {}
      @users = {}
      @slack_info = {}

      @slack = Slack::RPC::Client.new(@slack_token)
      auth_test = @slack.auth.test
      @slack_connection = auth_test.body
      raise "Error authenticating to Slack" unless @slack_connection['ok']
      update_channels
      update_users
      add_trigger trigger
    rescue Exception => msg # TODO: Refine
      abort "Error Initializing Slabot: #{msg}"
    end

    def bot_name
      @post_options[:username]
    end

    def slack
      @slack_connection
    end

    def <<(arg)
      case arg.class.name
      when 'String'
        add_channel arg
      when 'Slabot::Trigger'
        add_trigger arg
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

    # Can be called like: #channels, #channels(:subscribed) or #channels(:available)
    def channels(query_type = :available)
      if query_type == :available
        @slack.channels.list().body['channels'].map { |channel| channel['name'] }
      elsif query_type == :subscribed
        @channels.values.map { |ch| ch['name'] }
      else
        raise "Slabot#channels called with invalid argument #{all_or_available}"
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
                  slack_client = Slack::RPC::Client.new(@slack_token)
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
                        puts "be_a_bot received message: #{message['type']}: #{message.pretty_inspect}" if @debug
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

    def add_trigger(trigger)
      case trigger.class.name
      when 'Slabot::Trigger'
        @triggers << trigger if trigger
      when 'Array'
        trigger.each { |trig| add_trigger trig }
      when 'NilClass'
      end
    end

    def update_channels
      @channels = {}
      channel_criteria = @channel_criteria.length > 0 ? @channel_criteria : [%r{.*}]
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
      if defined?(message['username']) && message['username'] != self.bot_name()
        catch (:triggered) do
          @triggers.each do |trigger|
            trigger_response = trigger.check(text: message['text'], user: user, channel: @channels[channel]['name'])
            if trigger_response
              trigger_response = { text: trigger_response.to_s } if trigger_response.class.name != 'Hash'
              begin
                @slack.chat.postMessage @post_options.merge({ channel: channel }).merge(trigger_response)
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
