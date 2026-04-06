# frozen_string_literal: true

require 'date'
require 'toc_doc'

require_relative 'telegram/chat_service'

# Orchestrates availability checking and Telegram notifications for a single watch.
#
# @example
#   AvailabilityCheckService.new('dentist_paris', params, logger).call
class AvailabilityCheckService
  after_initialize :load_availabilities!

  # @param watch_name [String] human-readable watch identifier (used in log messages and notifications)
  # @param params [Hash] watch configuration hash from +config.yml+
  # @param logger [Logger] logger instance for output
  def initialize(watch_name, params, logger)
    @watch_name = watch_name
    @params     = params
    @logger     = logger
  end

  # Checks availability and notifies via Telegram if slots are found.
  #
  # @return [Hash] result with :watch_name, :total, :slots_by_date
  def call
    if @availabilities.total.to_i.zero?
      @logger.info("no availability found for #{@watch_name}")
      return { watch_name: @watch_name, total: 0, slots_by_date: {} }
    end

    message = format_message(@availabilities)
    Telegram::ChatService.send_message(message)
    @logger.info("#{@availabilities.total} slot(s) found for #{@watch_name} — notification sent")

    report(message)
  end

  private

  # Builds the result hash returned from {#call}.
  #
  # @return [Hash] with :watch_name, :total, :slots_by_date keys
  def report(_message)
    {
      watch_name: @watch_name,
      total: @availabilities.total,
      slots_by_date: @availabilities.slots.map(&:to_s)
    }
  end

  # Fetches availabilities from the Doctolib API and stores them in +@availabilities+.
  # Called automatically after +initialize+ via +after_initialize+.
  # If the first page returns no slots but more pages exist, loads the next page.
  def load_availabilities!
    @availabilities = TocDoc::Availability.where(
      visit_motive_ids: @params['visit_motive_ids'],
      agenda_ids: @params['agenda_ids'],
      practice_ids: @params['practice_ids'],
      start_date: resolve_date(@params['start_date']),
      telehealth: @params.fetch('telehealth', false),
      limit: @params.fetch('limit', 5)
    )

    @availabilities.load_next! if @availabilities.total.to_i.zero? && @availabilities.more?
  end

  # Resolves a date value from config. The string +"today"+ (or +nil+) maps to {Date.today};
  # any other value is parsed with {Date.parse}.
  #
  # @param value [String, nil]
  # @return [Date]
  def resolve_date(value)
    return Date.today if value.nil? || value.to_s.strip.downcase == 'today'

    Date.parse(value.to_s)
  end

  # Formats an availability collection into a Markdown message for Telegram.
  #
  # @param collection [TocDoc::Availability::Collection]
  # @return [String]
  def format_message(collection)
    lines = ["Doctowatch [#{@watch_name}]: slots found!\n"]

    collection.each do |avail|
      times = avail.slots.map { |slot| slot.strftime('%H:%M') }.join(', ')
      lines << "- #{avail.date.strftime('%a %-d %b')}: #{times}"
    end

    lines << "\n(#{collection.total} slots total)"
    lines.join("\n")
  end
end
