module InstantSlackBot #:nodoc:
  class Callback
  
    require 'pp'
    require 'set'
    require 'openssl'
    require 'webrick'

    attr_reader :server
    attr_accessor :server_url
  
    def initialize(options: nil, webrick_config: {})
      @webrick_config = DEFAULT_WEBRICK_CONFIG
      if options.has_key? :debug && options[:debug]
        @webrick_config.delete(:AccessLog)
        @webrick_config.delete(:Logger)
      end
      @webrick_config.merge! webrick_config
      
      @callbacks = {}
      @server_url = server_url.sub(/\/$/, '') if server_url
      @server_thread = launch_server_thread
    end
  
    def register(callback)
      id = random_sha1 until(id && !@callbacks.include?(id))
      @callbacks[id] = callback
      callback_url id
    end
  
    alias_method :<<, :register
  
    private
  
    def callback_url(id)
      sprintf "%s/%s", @server_url, id
    end
  
    def handler(req, res)
      path = req.path.sub(%r{^#{@url_prefix}/}, '')
      if CALLBACK_404S.include? path  
        res.status = 404
      elsif @callbacks.has_key? path
        cb_response = launch_callback(id: path, req: req, res: res)
        case cb_response.class.name
        when 'String'
          res.body = cb_response
        when 'WEBrick::HTTPResponse'
          res = cb_response
        else
          raise ArgumentError "Invalid callback response type"
        end
      else
        res.body = "Error, unused URL."
      end
    end
  
    def init_server
      if @webrick_config[:Port] == :random
        begin
          @server = WEBrick::HTTPServer.new @webrick_config.merge(
            { Port: 10_000 + rand(10_000) }
          )
        rescue Errno::EADDRINUSE
          nil
        end
      else
        @server = WEBrick::HTTPServer.new @webrick_config
      end
    end
  
    def launch_callback(id: nil, req: nil, res: nil)
      case @callbacks[id].class.name
      when 'String'
        @callbacks[id]
      when 'Proc'
        @callbacks[id].call(req, res)
      else
        raise ArgumentError "Invalid callback type: @callbacks[id].class.name"
      end
    end
  
    def launch_server_thread
      init_server until @server
      @server_url ||= sprintf('http://%s:%s',
                              @server.config[:ServerName],
                              @server.config[:Port].to_s)
      CALLBACK_ABORT_ON_SIGS.each do |sig| 
        trap(sig) do 
          server.shutdown
          abort
        end
      end
      server.mount_proc '/' do |req, res|
        handler(req, res)
      end
      Thread.new { @server.start }
    end
  
    def random_sha1
      OpenSSL::HMAC.new(rand.to_s, 'sha1').to_s
    end
  end
end
