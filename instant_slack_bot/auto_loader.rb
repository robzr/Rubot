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

    def master_add(file)
      unless load file
        puts "Error: could not load #{file}"
        return nil
      end
      class_name = get_class_name file 
      if eval "defined? #{class_name}.name"
        puts "Loading #{class_name}"
        @bots[file] = eval "#{class_name}.new"
        puts "GOT HERE"
      else
        puts "Error: cannot find #{class_name}" 
      end
      pp @bots[file]
      @master << @bots[file]
    rescue StandardError, msg
      puts "AutoLoader#master_add - error #{msg}"
    end

    def master_delete(file)
      return unless @bots.key? file
      @master.delete(@bots[file].id)
      @bots.delete(file)
    rescue StandardError, msg
      puts "AutoLoader#master_delete - error #{msg}"
    end

    def update_master(master = @master)
      while @changes.length > 0
        change = @changes.shift
        case change[:action]
        when :added
          master_add change[:file]
        when :deleted
          master_delete change[:file]
        when :changed
          master_delete change[:file]
          master_add change[:file]
        else
          raise ArgumentError, "Invalid change type"
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

    def get_class_name(file)
      file.gsub(/.*\//, '')
        .sub(/\.rb$/, '')
        .split(/_/)
        .map { |word| word.capitalize } 
        .join
        .sub(/.*/, '\&::\&')
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
