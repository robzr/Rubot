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
module InstantSlackBot
  require 'slack'  # slack-ruby gem
  require_relative 'instant_slack_bot/bot'
  require_relative 'instant_slack_bot/master'
  require_relative 'instant_slack_bot/slack_rtm.rb'
end
