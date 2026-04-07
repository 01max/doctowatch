# frozen_string_literal: true

require 'date'
require 'toc_doc'

require_relative 'telegram/chat_service'

# Orchestrates availability checking and Telegram notifications for a single watch.
#
# @example
#   AvailabilityCheckService.new('dentist_paris', params, logger).call
class AvailabilityCheckService
  attr_reader :availabilities

  # @param watch_name [String] human-readable watch identifier (used in log messages and notifications)
  # @param params [Hash] watch configuration hash from +config.yml+
  # @param logger [Logger] logger instance for output
  # @param previous_slots [Array<String>, nil] slot strings from the previous run, used to suppress
  #   duplicate notifications; pass +nil+ to always notify when slots are found
  def initialize(watch_name, params, logger, previous_slots = nil)
    @watch_name     = watch_name
    @params         = params
    @logger         = logger
    @previous_slots = previous_slots

    load_availabilities!
  end

  # Checks availability and notifies via Telegram if slots are found and have changed.
  #
  # @return [Hash] result with +:watch_name+, +:total+, +:slots_by_date+ keys
  def call
    if @availabilities.total.to_i.zero?
      @logger.info("no availability found for #{@watch_name}")
      return { watch_name: @watch_name, total: 0, slots_by_date: {} }
    end

    if slots_unchanged?
      @logger.info("#{@availabilities.total} slot(s) found for #{@watch_name} — unchanged, skipping notification")
      return report
    end

    notify!
    report
  end

  private

  # @return [Boolean] true if the current slots are identical to the previous run's slots
  def slots_unchanged?
    return false unless @previous_slots

    @availabilities.slots.map(&:to_s).sort == @previous_slots.sort
  end

  # Sends a Telegram notification with the current availability.
  # @return [void]
  def notify!
    message = format_message(@availabilities)
    reply_markup = Telegram::ChatService.build_inline_keyboard([booking_url_hash])
    Telegram::ChatService.new(**chat_params).deliver(message, reply_markup: reply_markup)
    @logger.info("#{@availabilities.total} slot(s) found for #{@watch_name} — notification sent")
  end

  # Builds the result hash returned from {#call}.
  #
  # @return [Hash] with +:watch_name+, +:total+, +:slots_by_date+ keys
  def report
    {
      watch_name: @watch_name,
      total: @availabilities.total,
      slots_by_date: @availabilities.slots.map(&:to_s)
    }
  end

  # Fetches availabilities from the Doctolib API and stores them in +@availabilities+.
  # Called automatically after +initialize+.
  # If the first page returns no slots but more pages exist, loads the next page.
  # @return [void]
  def load_availabilities!
    @availabilities = TocDoc::Availability.where(
      visit_motive_ids: @params['visit_motive_ids'],
      agenda_ids: @params['agenda_ids'],
      practice_ids: @params['practice_ids'],
      start_date: resolve_date(@params['start_date']),
      telehealth: @params.fetch('telehealth', false),
      limit: @params.fetch('limit', 5),
      booking_slug: @params['booking_slug']
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

  # Builds keyword arguments for {Telegram::ChatService#initialize}.
  # Returns the per-watch +telegram_chat_id+ from config if set, otherwise falls back
  # to the default chat ID from the environment.
  #
  # @return [Hash, nil]
  def chat_params
    return nil unless @params['telegram_chat_id']

    { chat_id: @params['telegram_chat_id'] }
  end

  # @return [String, nil] booking URL from the availability response, memoized
  def booking_url
    @booking_url ||= @availabilities.booking_url
  end

  # Builds the inline keyboard button hash for the booking URL.
  #
  # @return [Hash, nil] button hash or +nil+ if no booking URL is available
  def booking_url_hash
    return nil unless booking_url

    { text: '👀', url: booking_url }
  end
end
