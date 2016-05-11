module InstantSlackBot #:nodoc:
  class Callback
  
    require 'pp'
    require 'set'
    require 'openssl'
    require 'webrick'

    attr_accessor :url, :webrick
  
    # TODO: add expiration logic to avoid infinite memory drain
    # - Simplest way is a Queue with a max # of instances
    # - Could also do age based and/or # based
    def initialize(options: nil, webrick_config: {})
      @webrick_config = DEFAULT_WEBRICK_CONFIG
      if options.has_key? :debug && options[:debug]
        @webrick_config.delete(:AccessLog)
        @webrick_config.delete(:Logger)
      end
      @webrick_config.merge! webrick_config
      
      @callbacks = {}
      @path = (options[:path] || DEFAULT_CALLBACK_PATH)
        .sub(/^\//, '')
        .sub(/\/$/, '')
      @url = url.sub(/\/$/, '') if url
      @webrick_thread = init_webrick
    end
  
    def register(callback)
      id = random_sha1 until(id && !@callbacks.include?(id))
      @callbacks[id] = callback
      callback_url id
    end
  
    alias_method :<<, :register

    def start_webrick
      @webrick_thread = Thread.new { @webrick.start }
    end

    def stop_webrick
      Thread.kill(@webrick_thread)
      sleep 0.01 while @webrick_thread.alive
      @webrick_thread = nil
    end
  
    private
  
    def callback_url(id)
      sprintf(
        "%s/%s%s",
        @url,
        @path ? "#{@path}/" : '',
        id
      )
    end
  
    def handler(req, res)
      path = req.path.sub(%r{^/#{@path}/}, '')
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
  
    def init_webrick
      instantiate_webrick until @webrick
      @url ||= sprintf('http://%s:%s',
                              @webrick.config[:ServerName],
                              @webrick.config[:Port].to_s)
      CALLBACK_ABORT_ON_SIGS.each do |sig| 
        trap(sig) do 
          @webrick.shutdown
          abort
        end
      end
      @webrick.mount_proc "/#{@path}" do |req, res|
        handler(req, res)
      end
      start_webrick
    end

    def instantiate_webrick
      if @webrick_config[:Port] == :random
        begin
          @webrick = WEBrick::HTTPServer.new @webrick_config.merge(
            { Port: 10_000 + rand(10_000) }
          )
        rescue Errno::EADDRINUSE
          nil
        end
      else
        @webrick = WEBrick::HTTPServer.new @webrick_config
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
  
    def random_sha1
      OpenSSL::HMAC.new(rand.to_s, 'sha1').to_s
    end
  end
end
