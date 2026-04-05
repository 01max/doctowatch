# frozen_string_literal: true

require 'json'

# Writes a JSON report to a file for later consumption.
module ReportWriter
  REPORT_PATH = File.expand_path('../tmp/report.json', __dir__)

  def self.write(results)
    FileUtils.mkdir_p(File.dirname(REPORT_PATH))

    report = {
      generated_at: Time.now.utc.iso8601,
      watches: results.map { |r| serialize(r) }
    }

    File.write(REPORT_PATH, JSON.pretty_generate(report))
  end

  def self.serialize(result)
    if result[:error]
      { watch: result[:watch_name], status: 'error', error: result[:error] }
    elsif result[:total].to_i.zero?
      { watch: result[:watch_name], status: 'no_slots' }
    else
      { watch: result[:watch_name], status: 'slots_found', total: result[:total],
        slots_by_date: result[:slots_by_date] }
    end
  end
  private_class_method :serialize
end
