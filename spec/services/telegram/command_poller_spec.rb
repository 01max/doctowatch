# frozen_string_literal: true

require 'spec_helper'
require_relative '../../../services/telegram/command_poller'

RSpec.describe Telegram::CommandPoller do
  let(:bot_token) { 'test_token' }
  let(:chat_id)   { '123456' }
  let(:api_url)   { "https://api.telegram.org/bot#{bot_token}/getUpdates" }

  before do
    stub_const('ENV', ENV.to_h.merge('TELEGRAM_BOT_TOKEN' => bot_token,
                                     'TELEGRAM_DEFAULT_CHAT_ID' => chat_id))
  end

  def update(update_id:, chat:, text:)
    { 'update_id' => update_id, 'message' => { 'chat' => { 'id' => chat }, 'text' => text } }
  end

  describe '#disable_requested?' do
    subject(:poller) { described_class.new }

    it 'returns false when there are no pending updates' do
      stub_request(:get, api_url)
        .with(query: { timeout: '0' })
        .to_return(status: 200, body: { ok: true, result: [] }.to_json)

      expect(poller.disable_requested?).to be false
    end

    it 'returns true when the authorized chat sent /disable and acks the update' do
      stub_request(:get, api_url)
        .with(query: { timeout: '0' })
        .to_return(status: 200, body: {
          ok: true,
          result: [update(update_id: 42, chat: chat_id.to_i, text: '/disable')]
        }.to_json)
      ack = stub_request(:get, api_url).with(query: { offset: '43', timeout: '0' })
                                       .to_return(status: 200, body: { ok: true, result: [] }.to_json)

      expect(poller.disable_requested?).to be true
      expect(ack).to have_been_requested
    end

    it 'accepts /disable@botname' do
      stub_request(:get, api_url)
        .with(query: { timeout: '0' })
        .to_return(status: 200, body: {
          ok: true,
          result: [update(update_id: 7, chat: chat_id.to_i, text: '/disable@doctowatch_bot')]
        }.to_json)
      stub_request(:get, api_url).with(query: { offset: '8', timeout: '0' })
                                 .to_return(status: 200, body: { ok: true, result: [] }.to_json)

      expect(poller.disable_requested?).to be true
    end

    it 'ignores /disable from a different chat but still acks' do
      stub_request(:get, api_url)
        .with(query: { timeout: '0' })
        .to_return(status: 200, body: {
          ok: true,
          result: [update(update_id: 5, chat: 999, text: '/disable')]
        }.to_json)
      ack = stub_request(:get, api_url).with(query: { offset: '6', timeout: '0' })
                                       .to_return(status: 200, body: { ok: true, result: [] }.to_json)

      expect(poller.disable_requested?).to be false
      expect(ack).to have_been_requested
    end

    it 'ignores unrelated messages' do
      stub_request(:get, api_url)
        .with(query: { timeout: '0' })
        .to_return(status: 200, body: {
          ok: true,
          result: [update(update_id: 1, chat: chat_id.to_i, text: 'hello')]
        }.to_json)
      stub_request(:get, api_url).with(query: { offset: '2', timeout: '0' })
                                 .to_return(status: 200, body: { ok: true, result: [] }.to_json)

      expect(poller.disable_requested?).to be false
    end

    it 'returns false when the API call fails' do
      stub_request(:get, api_url)
        .with(query: { timeout: '0' })
        .to_return(status: 500, body: '')

      expect(poller.disable_requested?).to be false
    end
  end
end
