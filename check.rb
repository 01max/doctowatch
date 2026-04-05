# frozen_string_literal: true

require 'logger'
require 'yaml'

require_relative 'services/availability_check_service'

# Load .env in development (not in CI)
unless ENV['CI']
  require 'dotenv'
  Dotenv.load
end

logger = Logger.new($stdout)
logger.progname = 'doctowatch'

config_path = File.expand_path('config.yml', __dir__)

unless File.exist?(config_path)
  logger.error("config.yml not found at #{config_path}")
  exit 1
end

config = YAML.safe_load_file(config_path)

if config.nil? || config.empty?
  logger.error('config.yml is empty or invalid')
  exit 1
end

success = true

config.each do |watch_name, params|
  AvailabilityCheckService.new(watch_name, params, logger).call
rescue StandardError => e
  logger.error("#{watch_name}: #{e.message}")
  success = false
end

exit(success ? 0 : 1)
