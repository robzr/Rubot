# InstantSlackBot::SlackRTM - Slack RTM API class
#
# This class is based on Rémi Delhaye's slack-rtm-api
#   http://github.com/rdlh/slack-rtm-api

require 'json'
require 'net/http'
require 'socket'
require 'websocket/driver'
require 'logger'
include IO::WaitReadable

module InstantSlackBot

  class SlackRTM
    VALID_DRIVER_EVENTS = [:open, :close, :message, :error]
    RTM_API_URL = 'https://slack.com/api/rtm.start'

    attr_accessor :auto_reconnect, :debug, :ping_threshhold, :select_timeout, :token
    attr_reader :connection_status

    def initialize(
      auto_start: true,
      auto_reconnect: true,
      debug: false,
      open_wait_timeout: 15,
      ping_threshold: 15,
      select_timeout: 0.01, # worst case adds 10ms latency to sends
      token: nil
    )
      @auto_reconnect = auto_reconnect
      @debug = debug
      @ping_threshold = ping_threshold
      @select_timeout = select_timeout
      @token = token


      # one of [:closed, :connecting, :initializing, :open]
      @connection_status = :closed
      @event_handlers = {}
      @events_queue = []
      @thread = nil

      @logger = Logger.new(STDOUT) if @debug

      if token
        @url = get_initial_url
        start if auto_start
        wait_for_open(open_wait_timeout: open_wait_timeout) if open_wait_timeout
      else
        raise ArgumentError.new 'InstantSlackBot::SlackRTM missing token'
      end
    end

    def bind(event_type: nil, event_handler: nil)
      unless VALID_DRIVER_EVENTS.include? event_type
        raise ArgumentError.new "Invalid Event (#{event_type}), valid events " \
          "are: #{VALID_DRIVER_EVENTS}"
      end
      @event_handlers[event_type] = event_handler
    end

    def close
      @connection_status = :closed
      return unless @thread
      @thread.kill
      @thread = nil 
      @driver.close 
    end

    def send(message)
      message[:id] = message_id
      @events_queue << message.to_json
    end

    alias_method :<<, :send

    def start
      @thread = Thread.new do
        connect_to_slack
        loop do
          check_ws if @connection_status != :closed
        end
      end
      @thread.abort_on_exception = true
    end

    private

    def check_ws
      if IO.select([@socket], nil, nil, @select_timeout)
        data = @socket.readpartial 4096
        @driver.parse data unless data.nil? || data.empty?
      end
      handle_events_queue
      tdiff = Time.new.to_i - @last_activity
      if Time.new.to_i - @last_activity > @ping_threshold
        @driver.ping
        @last_activity = Time.new.to_i
      end
    end

    def connect_to_slack
      return if @connection_status == :open
      @connection_status = :connecting
      @socket = OpenSSL::SSL::SSLSocket.new TCPSocket.new(@url.host, 443)
      @socket.connect
      @driver = WebSocket::Driver.client \
        InstantSlackBot::WebSocketDriverClient.new(@url.to_s, @socket)
      register_driver_events
      @last_activity = Time.now.to_i
      @driver.start
    end

    def handle_events_queue
      while event = @events_queue.shift
        send_log "WebSocket::Driver send #{event}"
        @driver.text event
      end
    end

    def get_initial_url
      req = Net::HTTP.post_form URI(RTM_API_URL), token: @token
      body = JSON.parse req.body
      if body['ok']
        URI body['url']
      else
        raise ArgumentError.new "Slack error: #{body['error']}"
      end
    end
    
    def message_id
      @message_id = 0 unless defined? @message_id
      @message_id += 1
    end       

    def register_driver_events 
      register_driver_open
      register_driver_close
      register_driver_error
      register_driver_message
    end

    def register_driver_close
      @driver.on :close do |event|
        send_log "WebSocket::Driver received a close event"
        @event_handlers[:close].call if @event_handlers[:close]
        @connection_status = :closed
        connect_to_slack if @auto_reconnect
      end
    end

    def register_driver_error
      @driver.on :error do |event|
        @last_activity = Time.new.to_i
        send_log "WebSocket::Driver received an error"
        @event_handlers[:error].call if @event_handlers[:error]
      end
    end

    def register_driver_message
      @driver.on :message do |event|
        data = JSON.parse event.data
        @last_activity = Time.new.to_i
        send_log "WebSocket::Driver received an event with data: #{data}"
        case data['type']
        when 'hello'
          @connection_status = :open
        when 'reconnect_url'
          @url = data['url']
          send_log "InstantSlackBot::SlackRTM#@driver.on :message URL Updated #{@url}"
        else
          @event_handlers[:message].call data unless @event_handlers[:message].nil?
        end
      end
    end

    def register_driver_open
      @driver.on :open do
        @connection_status = :initializing
        @last_activity = Time.new.to_i
        send_log "WebSocket::Driver :open"
        @event_handlers[:open].call if @event_handlers[:open]
      end
    end

    def send_log(log)
      @logger.info(log) if @debug
    end

    def wait_for_open(open_wait_timeout: open_wait_timeout)
      start_time = Time.new.to_i
      while @connection_status != :open && Time.new.to_i - start_time < open_wait_timeout do
        sleep @select_timeout
      end
      raise StandardError, "Timed out waiting for open" unless @connection_status == :open
    end

  end

  class WebSocketDriverClient
    attr_accessor :url, :socket

    def initialize(url, socket)
      @url = url
      @socket = socket
    end

    def write(*args)
      self.socket.write(*args)
    end
  end

end
