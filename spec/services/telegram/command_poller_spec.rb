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

  def stub_updates(updates, offset: nil)
    query = offset ? { offset: offset.to_s, timeout: '0' } : { timeout: '0' }
    stub_request(:get, api_url)
      .with(query: query)
      .to_return(status: 200, body: { ok: true, result: updates }.to_json)
  end

  describe '#disable_requested?' do
    context 'with a baseline update_id from the previous run' do
      subject(:poller) { described_class.new(since_update_id: 100) }

      it 'queries Telegram with offset = since + 1' do
        stub_updates([], offset: 101)

        expect(poller.disable_requested?).to be false
      end

      it 'returns true when /disable arrives from the authorized chat and acks' do
        stub_updates([update(update_id: 101, chat: chat_id.to_i, text: '/disable')], offset: 101)
        ack = stub_updates([], offset: 102)

        expect(poller.disable_requested?).to be true
        expect(ack).to have_been_requested
        expect(poller.last_update_id).to eq 101
      end

      it 'accepts /disable@botname' do
        stub_updates([update(update_id: 7, chat: chat_id.to_i, text: '/disable@doctowatch_bot')], offset: 101)
        stub_updates([], offset: 8)

        expect(poller.disable_requested?).to be true
      end

      it 'ignores /disable from a different chat but still acks' do
        stub_updates([update(update_id: 150, chat: 999, text: '/disable')], offset: 101)
        ack = stub_updates([], offset: 151)

        expect(poller.disable_requested?).to be false
        expect(ack).to have_been_requested
      end

      it 'ignores unrelated messages' do
        stub_updates([update(update_id: 150, chat: chat_id.to_i, text: 'hello')], offset: 101)
        stub_updates([], offset: 151)

        expect(poller.disable_requested?).to be false
      end

      it 'retains the baseline update_id when no updates are returned' do
        stub_updates([], offset: 101)

        poller.disable_requested?
        expect(poller.last_update_id).to eq 100
      end
    end

    context 'on the first run (no baseline)' do
      subject(:poller) { described_class.new(since_update_id: nil) }

      it 'does not act on historical /disable messages and acks to establish a baseline' do
        stub_updates([update(update_id: 42, chat: chat_id.to_i, text: '/disable')])
        ack = stub_updates([], offset: 43)

        expect(poller.disable_requested?).to be false
        expect(ack).to have_been_requested
        expect(poller.last_update_id).to eq 42
      end

      it 'leaves last_update_id nil when no updates are pending' do
        stub_updates([])

        poller.disable_requested?
        expect(poller.last_update_id).to be_nil
      end
    end

    it 'returns false when the API call fails' do
      stub_request(:get, api_url)
        .with(query: { timeout: '0' })
        .to_return(status: 500, body: '')

      expect(described_class.new.disable_requested?).to be false
    end
  end
end
