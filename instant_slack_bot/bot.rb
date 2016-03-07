module InstantSlackBot #:nodoc:
  require 'pp'
  require 'slack'

  # Bot class is used to define a set of conditions, which, once met, result in an action.
  class Bot
    attr_accessor :action, :logic, :debug
    attr_reader :conditions

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
    end

    # Used to assign actions to this Bot instance
    # @param arg [String] static text to be printed
    # @param arg [Proc] Proc is run, the evaluation is printed
    def action=(arg)
      case arg.class.name
      when 'Proc'
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
      when 'String', 'Regexp', 'Proc'
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
    def check(args)
      run_action = false
      case @logic
      when :or
        @conditions.each { |cond| run_action ||= check_condition args.merge({ condition: cond }) }
      when :and
        run_action = true
        @conditions.each { |cond| run_action &&= check_condition args.merge({ condition: cond }) }
      end
      @action.call(args) if run_action
    end

    private

    # Called by `#check` to evalute each condition
    # @param :condition [String, Regexp, Proc] Condition to be evaluated
    # @param :channel [String] (see #check)
    # @param :text [String] (see #check)
    # @param :user [String] (see #check)
    # @param :message [SlackMessage] Slack Message hash
    def check_condition(condition: condition, text: nil, user: nil, channel: nil, message: nil)
      case condition.class.name
      when 'String'
        run_action = true if /\b#{condition}\b/i.match(text)
      when 'Regexp'
        run_action = true if condition.match(text)
      when 'Proc'
        run_action = true if condition.call(text: text, user: user, channel: channel)
      else
        raise "Condition (#{condition}) is an invalid class (#{condition.class.name})"
      end
    end
  end
end
