# frozen_string_literal: true

require 'httparty'
require 'json'

module Telegram
  # Polls the Telegram Bot API for pending updates and detects control commands
  # sent from the authorized chat.
  #
  # The GitHub Actions cron has no long-lived process, so we use +getUpdates+ (long
  # polling disabled) at the start of each run rather than webhooks. After reading
  # updates, we acknowledge them by calling +getUpdates+ again with
  # +offset = last_update_id + 1+ so the same commands are not replayed on the
  # next run.
  class CommandPoller
    DISABLE_COMMAND = '/disable'

    # @param authorized_chat_id [String] only messages from this chat trigger commands
    def initialize(authorized_chat_id: ENV.fetch('TELEGRAM_DEFAULT_CHAT_ID'))
      @authorized_chat_id = authorized_chat_id.to_s
    end

    # @return [Boolean] true if an authorized +/disable+ command is pending
    def disable_requested?
      updates = fetch_updates
      return false if updates.empty?

      requested = updates.any? { |u| disable_command?(u) }
      ack(updates.last['update_id'])
      requested
    end

    private

    def fetch_updates
      response = HTTParty.get(api_url('getUpdates'), query: { timeout: 0 })
      return [] unless response.success?

      body = JSON.parse(response.body)
      Array(body['result'])
    rescue JSON::ParserError
      []
    end

    def ack(last_update_id)
      HTTParty.get(api_url('getUpdates'), query: { offset: last_update_id + 1, timeout: 0 })
    end

    def disable_command?(update)
      message = update['message'] || update['channel_post']
      return false unless message
      return false unless message.dig('chat', 'id').to_s == @authorized_chat_id

      text = message['text'].to_s.strip.downcase
      text == DISABLE_COMMAND || text.start_with?("#{DISABLE_COMMAND}@")
    end

    def api_url(method)
      "https://api.telegram.org/bot#{ENV.fetch('TELEGRAM_BOT_TOKEN')}/#{method}"
    end
  end
end
