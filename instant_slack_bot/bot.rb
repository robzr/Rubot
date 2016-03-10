# InstantSlackBot::Bot class - defines a single Bot instance

module InstantSlackBot #:nodoc:
  require 'pp'
  require 'slack'
  require 'base64'
  require 'openssl'

  # Bot class is used to define a set of conditions, which, once met, result in
  #   an action.
  class Bot
    attr_accessor :action, :conditions, :channels, :options
    attr_reader :id

    # Instantiates a Bot object
    # @note `:action` and `:conditions` are both required, but can be populated
    #   after instantiation using +action=+ and +conditions=+
    # @param :action [String, Proc] called when conditions are met
    # @param :conditions [String, Regexp, Proc] evaluated to determine when to
    #   run the `:action`
    # @param :debug [Boolean] used to enable debug output to stdout
    # @param :logic [Symbol] `:and` or `:or` determines how to evaluate
    #   multiple conditions
    def initialize(
      action: nil,
      conditions: nil,
      channels: nil,
      options: {}
    )
      self.action = action
      self.conditions = conditions
      @id = OpenSSL::HMAC.new(rand.to_s, 'sha1').to_s
      @options = DEFAULT_BOT_OPTIONS.merge(options)
    end

    # Method used to run the bots action. Override this when using
    # a Class based bot.
    #
    def action(arg)
      if @action.class.name == 'Proc'
        @action.call(arg[:message])
      elsif @action.class.name == 'Method'
        @action.call(arg)
      else
        raise StandardError,
          "InstantSlackBot::Bot#action passed invalid class type #{msg}"
      end
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

    # Used to evaluate the Bots conditions, and run the action if needed.
    #   Normally this is only called by the Master.
    # @param :channel [String] Channel name where the message originated
    # @param :text [String] Text of the message
    # @param :user [String] Username who wrote the message
    def conditions(arg)
      run_action = false
      case options[:condition_logic]
      when :or
        @conditions.each do |condition|
          if condition.class.name == 'Proc'
            run_action ||= check_condition arg.merge({ condition: condition })[:message]
          else
            run_action ||= check_condition arg.merge({ condition: condition })
          end
        end
      when :and
        run_action = true
        @conditions.each do |condition|
          if condition.class.name == 'Proc'
            run_action &&= check_condition arg.merge({ condition: condition })[:message]
          else
            run_action &&= check_condition arg.merge({ condition: condition })
          end
        end
      end
      run_action
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
      when 'NilClass'
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

    private

    # Called by `#check` to evalute each condition
    # @param :condition [String, Regexp, Proc] Condition to be evaluated
    # @param :channel [String] (see #check)
    # @param :text [String] (see #check)
    # @param :user [String] (see #check)
    # @param :message [SlackMessage] Slack Message hash
    def check_condition(condition: nil, message: nil)
#pp condition
#pp message
      case condition.class.name
      when 'String'
        true if /\b#{condition}\b/i.match(message['text'])
      when 'Regexp'
        true if condition.match(message['text'])
      when 'Proc', 'Method'
        true if condition.call(message: message)
      else
        raise "Condition (#{condition}) is an invalid class " \
          "(#{condition.class.name})"
      end
    end
  end
end
