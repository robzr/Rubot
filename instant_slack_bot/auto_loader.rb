# InstantSlackBot::AutoLoader monitors a directory in a background thread for
#   files that are added, deleted or changed and loads a public queue (@changes)
#   with a description of the event

module InstantSlackBot

  require 'pp'
  require 'set'

  class AutoLoader
    attr_accessor :changes

    def initialize(
      directory: '.', 
      glob: '*.rb', 
      master: nil, 
      refresh: 0.5
    )
      @glob = "#{directory}/#{glob}"
      @master = master
      @refresh = refresh

      @bots = {}
      @changes = Queue.new
      @files = {}
      launch_watcher_thread
    end

    def update_master(master = @master)
      while @changes.length > 0
        change = @changes.shift
        case change[:action]
        when :added
          master_add(file)
        when :deleted
          master_delete(file)
        when :changed
          master_delete(file)
          master_add(file)
        end
      end
    end

    private

    def file_stat(file)
      stat = File.stat(file)
      {
        size: stat.size,
        mtime: stat.mtime
      }
    end

    def compare_directory
      new_files = load_directory
      @files.each do |file_name, stat|
        if new_files.key? file_name
          file_changed file_name unless new_files[file_name] == stat
          new_files.delete(file_name) 
        else
          file_deleted file_name
        end
      end
      new_files.each do |file_name, stat|
        file_added file_name
      end
    end

    def file_added(file)
      @files[file] = file_stat file
      @changes << { action: :added, file: file }
    end

    def file_changed(file)
      @files[file] = file_stat file
      @changes << { action: :changed, file: file }
    end

    def file_deleted(file)
      @files.delete(file)
      @changes << { action: :deleted, file: file }
    end

    def master_add(file)
      # test if file is valid, if not, complain & don't add to @bot
      @bot[file] = Bot.new(options)
      @master << @bot[file]
    end

    def master_delete(file)
      return unless @bot.key? file
# Need to add this method
#      @master.unload(@bot[file])
      @bot.delete(file)
    end

    def launch_watcher_thread
      Thread.new do
        loop do 
          time_starting = Time.new.to_f
          compare_directory
          update_master if @master
          delay = @refresh - (Time.new.to_f - time_starting)
          sleep delay if delay > 0
        end
      end
    end

    def load_directory
      files = {}
      Dir[@glob].each do |file|
        files[file] = file_stat file
      end
      files
    end

  end
end
