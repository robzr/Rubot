#
# InstantSlackBot::Bot - Bot class
#
#   Each Bot has one or more conditions and a single action, which happens when
#     any of the conditions are met (logic: :or behavior).  Alternately, 
#     logic: :and can be used, which requires all the conditions to be met.
#
module InstantSlackBot
  require 'pp'
  require 'slack'

  class Bot
    attr_accessor :action, :logic, :debug
    attr_reader :conditions

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

    def action=(arg)
      case arg.class.name
      when 'Proc'
        @action = arg
      when 'String'
        @action = proc { arg }
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

    def check_condition(condition: condition, text: nil, user: nil, channel: nil)
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
