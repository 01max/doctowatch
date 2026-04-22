# frozen_string_literal: true

require 'json'
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

previous_report_path = File.expand_path('tmp/previous/report.json', __dir__)
previous_slots = begin
  data = JSON.parse(File.read(previous_report_path))
  data['watches'].to_h { |w| [w['watch'], w['slots_by_date'] || []] }
rescue StandardError
  logger.warn("Previous report not found or invalid at #{previous_report_path}, starting fresh")
  {}
end

success = true
results = []

config.each do |watch_name, params|
  results << AvailabilityCheckService.new(watch_name, params, logger, previous_slots[watch_name]).call
rescue StandardError => e
  logger.error("#{watch_name}: #{e.message}")
  results << { watch_name: watch_name, error: e.message }
  success = false
end

require_relative 'services/report_writer'
ReportWriter.write(results)

exit(success ? 0 : 1)
