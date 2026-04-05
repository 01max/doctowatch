# frozen_string_literal: true

require 'httparty'

module Telegram
  # Sends messages to a Telegram chat via the Bot API.
  #
  # Credentials are read from the environment variables +TELEGRAM_BOT_TOKEN+
  # and +TELEGRAM_CHAT_ID+.
  #
  # @example
  #   Telegram::ChatService.send_message("Hello!")
  class ChatService
    include HTTParty

    BASE_URL = 'https://api.telegram.org'

    class << self
      # Sends a Markdown-formatted message to the configured Telegram chat.
      #
      # @param text [String] message body (supports Telegram Markdown)
      # @raise [RuntimeError] if +TELEGRAM_BOT_TOKEN+ or +TELEGRAM_CHAT_ID+ env vars are missing
      # @raise [HTTParty::Error] on network or HTTP-level failure
      # @return [HTTParty::Response]
      def send_message(text)
        token   = ENV.fetch('TELEGRAM_BOT_TOKEN')
        chat_id = ENV.fetch('TELEGRAM_CHAT_ID')

        post(
          "#{BASE_URL}/bot#{token}/sendMessage",
          body: { chat_id: chat_id, text: text, parse_mode: 'Markdown' }
        )
      end
    end
  end
end
