# InstantSlackBot default options

module InstantSlackBot #:nodoc:
  require 'webrick'

  CALLBACK_404S = ['favicon.ico'].to_set

  CALLBACK_ABORT_ON_SIGS = ['INT', 'TERM']

  DEFAULT_CALLBACK_PATH = 'InstantSlackBot'

  DEFAULT_WEBRICK_CONFIG = {
    AccessLog: [],
    DocumentRoot: nil,
    Logger: WEBrick::Log.new(nil, 0),
    Port: :random
  }

  DEFAULT_MAX_THREADS = 50
  THREAD_THROTTLE_DELAY = 0.001

  DEFAULT_BOT_OPTIONS = {
    condition_logic: :or  # :or or :and
  }

  DEFAULT_MASTER_OPTIONS = {
    channels: nil,        # nil == all channels
    debug: false,
    max_threads: DEFAULT_MAX_THREADS,
    reply_to: :origin,    # :origin, :direct_message or 'channelname'
    use_api: :webrpc      # :webrpc or :rtm - rtm does not allow icons or links
                          #    in messages :rtm bots must be /invited 
  }

  DEFAULT_BOT_POST_OPTIONS = {}

  DEFAULT_MASTER_POST_OPTIONS = { 
    'as_user' => false,
#    'icon_url' => 
#      'https://raw.githubusercontent.com/robzr/instant-slack-bot/master/examples/pics/bender3.png',
    'link_names' => 'true', 
    'parse' => 'none',
    'unfurl_links' => 'false'
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
end
