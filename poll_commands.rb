# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'logger'

require_relative 'services/github_workflow_service'
require_relative 'services/telegram/chat_service'
require_relative 'services/telegram/command_poller'

unless ENV['CI']
  require 'dotenv'
  Dotenv.load
end

logger = Logger.new($stdout)
logger.progname = 'doctowatch-commands'

PREVIOUS_STATE_PATH = File.expand_path('tmp/previous/command_state.json', __dir__)
STATE_PATH = File.expand_path('tmp/command_state.json', __dir__)
CHECK_WORKFLOW = 'check.yml'

since_update_id = begin
  JSON.parse(File.read(PREVIOUS_STATE_PATH))['last_update_id']
rescue StandardError
  logger.warn("No previous command state at #{PREVIOUS_STATE_PATH} — establishing baseline")
  nil
end

poller = Telegram::CommandPoller.new(since_update_id: since_update_id)
commands = poller.commands

commands.each do |command|
  case command
  when :disable
    logger.warn('/disable received — disabling check workflow')
    GithubWorkflowService.new.disable(CHECK_WORKFLOW)
    Telegram::ChatService.new.deliver('Doctowatch: check workflow disabled.')
  when :enable
    logger.warn('/enable received — enabling check workflow')
    GithubWorkflowService.new.enable(CHECK_WORKFLOW)
    Telegram::ChatService.new.deliver('Doctowatch: check workflow enabled.')
  end
end

FileUtils.mkdir_p(File.dirname(STATE_PATH))
File.write(STATE_PATH, JSON.pretty_generate(last_update_id: poller.last_update_id))
