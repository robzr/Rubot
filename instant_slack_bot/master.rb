# This file is part of instant-slack-bot.
# Copyright 2016 Rob Zwissler (rob@zwissler.org)
# https://github.com/robzr/instant-slack-bot
#
# Distributed under the terms of the GNU Affero General Public License
# 
# instant-slack-bot is free software: you can redistribute it and/or modify it 
# under the terms of the GNU Affero General Public License as published by the
# Free Software Foundation, either version 3 of the License, or (at your 
# option) any later version.
#   
# instant-slack-bot is distributed in the hope that it will be useful, but 
# WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY 
# or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU Affero General Public 
# License for more details.
#   
# You should have received a copy of the GNU Affero General Public License
# along with instant-slack-bot. If not, see <http://www.gnu.org/licenses/>.
#
# InstantSlackBot::Master class - multiple Bots run in a single Master class

module InstantSlackBot
  require 'pp'
  require 'slack'
  require 'thread'

  class Master
    DEFAULT_BOT_NAME = 'InstantSlackBot'
    DEFAULT_MAX_THREADS = 50
    DEFAULT_POST_OPTIONS = { 
      icon_emoji: ':squirrel:', 
      link_names: 'true', 
      unfurl_links: 'false', 
      parse: 'none' 
    }
    MESSAGE_TYPES_UPDATE_USERS = %w{ 
      channel_join
      channel_leave
      team_join 
      user_change 
    }
    MESSAGE_TYPES_UPDATE_CHANNELS = %w{
      channel_archive
      channel_created
      channel_deleted
      channel_rename
      channel_unarchive
    }
    THREAD_THROTTLE_DELAY = 0.001

    attr_accessor :post_options, :bots, :max_threads

    def initialize(
      bots: nil,
      channels: nil,
      debug:false,
      max_threads: DEFAULT_MAX_THREADS,
      name: DEFAULT_BOT_NAME,
      post_options: {},
      token: nil
    )
      @bots = {}
      @channel_criteria = channels
      @debug = debug
      @max_threads = max_threads
      @post_options = DEFAULT_POST_OPTIONS
      @post_options.merge!({ username: name }) if name
      @post_options.merge!(post_options)
      @token = token

      @slack = nil
      @channels = {}
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
    rescue StandardError => msg
      abort "Error Initializing Slack WebRPC: #{msg}"
    end

    def connect_to_slack_rtm
      @slack_rtm = InstantSlackBot::SlackRTM.new(
        token: @token,
        debug: false)
      add_to_queue = proc { |message| @receive_message_queue << message }
      @slack_rtm.bind(event_type: :message, event_handler: add_to_queue)
    rescue StandardError => msg
      abort "Error Initializing Slack RTM: #{msg}"
    end

    def name
      @post_options[:username]
    end

    def name=(name)
      @post_options[:username] = name
    end

    def slack
      # TODO: merge RTM connection info
      @slack_connection.merge({ })
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
      end
    end

    def users
      @users.values.map { |user| user['name'] }
    end

    # Event loop - does not return (yet).
    def run
      loop do
        if message = @receive_message_queue.shift then
          # First we process potential bot events
          update_users if MESSAGE_TYPES_UPDATE_USERS.include? message['type']
          update_channels if MESSAGE_TYPES_UPDATE_CHANNELS.include? message['type']
          process_message(message: message) || @receive_message_queue.unshift(message)
        else
          sleep THREAD_THROTTLE_DELAY
        end
        compact_bot_threads
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
      end
    end

    def compact_bot_threads
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
        # TODO: test
        @channels[@message['channel'].to_s]['name']
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

    def process_message(message: message)
      return true if message.key?('subtype') && message['subtype'] == 'bot_message'
      return true if message['type'] != 'message'
      return false if thread_count >= @max_threads
      @bots.each do |bot_id, bot| 
        @threads[bot_id] << Thread.new {
          if bot.check_conditions(message: message_plus(message: message))
            # TODO: submit an is_typing method to API
            bot_response = bot.run_action(message: message_plus(message: message))
            begin
              if bot_response
                if bot_response.class.name != 'Hash'
                  bot_response = { text: bot_response.to_s }
                end
                @slack.chat.postMessage @post_options.merge({
                  channel: message['channel']
                }).merge(bot_response)
              end
            rescue StandardError => msg
              abort "process_message postMessage error: #{msg}"
            end
          end
        }
      end
      true
    end

    def thread_count
      @threads.values.map { |thread_a| thread_a.length }.reduce(:+)
    end
  end
end
