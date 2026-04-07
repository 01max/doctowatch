# frozen_string_literal: true

require 'httparty'

module Telegram
  # Sends messages to a Telegram chat via the Bot API.
  #
  # Credentials are read from the environment variable +TELEGRAM_BOT_TOKEN+
  #
  # @example
  #   Telegram::ChatService.new.send("Hello!")
  class ChatService
    attr_reader :chat_id

    def initialize(chat_id: ENV.fetch('TELEGRAM_DEFAULT_CHAT_ID'))
      @chat_id = chat_id
    end

    def deliver(text, parse_mode: 'Markdown', reply_markup: nil)
      HTTParty.post(
        "https://api.telegram.org/bot#{ENV.fetch('TELEGRAM_BOT_TOKEN')}/sendMessage",
        body: build_body(text, parse_mode, reply_markup)
      )
    end

    private

    def build_body(text, parse_mode, reply_markup)
      body = { chat_id: chat_id, text: text, parse_mode: parse_mode }
      body[:reply_markup] = reply_markup.to_json if reply_markup
      body
    end

    class << self
      # Helper method to create inline keyboard markup
      # If a single array of buttons is provided, it will wrap it in an array to create a single row
      def build_inline_keyboard(buttons)
        return nil if buttons.nil? || buttons.empty?

        keyboard = if buttons.first.is_a?(Array)
                     buttons # Already in correct format
                   else
                     [buttons] # Make it an array of arrays (single row)
                   end

        { inline_keyboard: keyboard }
      end
    end
  end
end
