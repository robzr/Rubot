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
# InstantSlackBot::Bot class - defines a single Bot instance

module InstantSlackBot #:nodoc:
  require 'pp'
  require 'slack'
  require 'base64'
  require 'openssl'

  # Bot class is used to define a set of conditions, which, once met, result in an action.
  class Bot
    attr_accessor :action, :logic, :debug
    attr_reader :conditions, :id

    # Instantiates a Bot object
    # @note `:action` and `:conditions` are both required, but can be populated
    #   after instantiation using +action=+ and +conditions=+
    # @param :action [String, Proc] called when conditions are met
    # @param :conditions [String, Regexp, Proc] evaluated to determine when to
    #   run the `:action`
    # @param :debug [Boolean] used to enable debug output to stdout
    # @param :logic [Symbol] `:and` or `:or` determines how to evaluate multiple conditions
    def initialize(
      action: nil, 
      conditions: nil, 
      debug: false,
      logic: :or
    )
      @logic = logic
      self.action = action
      self.conditions = conditions
      @id = random_sha1
    end

    # Used to assign actions to this Bot instance
    # @param arg [String] static text to be printed
    # @param arg [Proc] Proc is run, the evaluation is printed
    def action=(arg)
      case arg.class.name
      when 'Proc', 'Method'
        @action = arg
      when 'String'
        @action = proc { arg }
      end
    end

    # Used to assign conditions to this Bot instance
    # @param arg [String, Regexp] Matches messages in Slack channels
    # @param arg [Proc] Proc is run, the evaluation is printed
    # @param arg [Array] One or more of Strings, Regexps, Procs, which are
    #   evaluated using boolean AND or OR logic, based on the value of 
    #   `#logic`
    def conditions=(arg)
      @conditions = []
      case arg.class.name
      when 'Array'
        @conditions += arg
      when 'String', 'Regexp', 'Proc', 'Method'
        @conditions << arg
      else
        raise "Condition (#{arg}) is an invalid class (#{arg.class.name})"
      end
    end

    # Adds a condition or conditions to this Bot instance
    # @param arg [String, Regexp] (see #conditions=)
    # @param arg [Proc] (see #conditions=)
    # @param arg [Array] (see #conditions=)
    def <<(arg)
      @conditions << arg
    end

    # Used to evaluate the Bots conditions, and run the action if needed.
    #   Normally this is only called by the Master.
    # @param :channel [String] Channel name where the message originated
    # @param :text [String] Text of the message
    # @param :user [String] Username who wrote the message
    def check_conditions(args)
      run_action = false
      case @logic
      when :or
        @conditions.each do |cond|
          if cond.class.name == 'Proc'
            run_action ||= check_condition args.merge({ condition: cond })[:message]
          else
            run_action ||= check_condition args.merge({ condition: cond })
          end
        end
      when :and
        run_action = true
        @conditions.each do |cond| 
          if cond.class.name == 'Proc'
            run_action &&= check_condition args.merge({ condition: cond })[:message]
          else
            run_action &&= check_condition args.merge({ condition: cond })
          end
        end
      end
      run_action
    end

    def run_action(args)
      if @action.class.name == 'Proc'
        @action.call(args[:message])
      else
        @action.call(args)
      end
    end

    private

    # Called by `#check` to evalute each condition
    # @param :condition [String, Regexp, Proc] Condition to be evaluated
    # @param :channel [String] (see #check)
    # @param :text [String] (see #check)
    # @param :user [String] (see #check)
    # @param :message [SlackMessage] Slack Message hash
    def check_condition(condition: nil, message: nil)
      case condition.class.name
      when 'String'
        true if /\b#{condition}\b/i.match(message['text'])
      when 'Regexp'
        true if condition.match(message['text'])
      when 'Proc', 'Method'
        true if condition.call(message: message)
      else
        raise "Condition (#{condition}) is an invalid class (#{condition.class.name})"
      end
    end

    def random_sha1
      OpenSSL::HMAC.new(rand.to_s, 'sha1').to_s
    end
  end
end
