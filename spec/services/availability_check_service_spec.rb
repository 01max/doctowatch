# frozen_string_literal: true

require 'spec_helper'
require 'logger'
require_relative '../../services/availability_check_service'

RSpec.describe AvailabilityCheckService do
  subject(:service) { described_class.new(watch_name, params, logger, previous_slots) }

  let(:watch_name) { 'dentist_paris' }
  let(:params) do
    {
      'visit_motive_ids' => 123,
      'agenda_ids' => 456,
      'practice_ids' => 789
    }
  end
  let(:logger)         { instance_double(Logger, info: nil, warn: nil, error: nil) }
  let(:previous_slots) { nil }

  let(:collection) { instance_double(TocDoc::Availability::Collection) }

  before do
    allow(TocDoc::Availability).to receive(:where).and_return(collection)
    allow(collection).to receive(:total).and_return(0)
    allow(collection).to receive(:more?).and_return(false)
    allow(collection).to receive(:slots).and_return([])
    allow(collection).to receive(:booking_url).and_return(nil)
  end

  describe '#call' do
    context 'when no slots are available' do
      it 'returns a no-slots result hash' do
        result = service.call

        expect(result).to eq(watch_name: 'dentist_paris', total: 0, slots_by_date: {})
      end

      it 'logs that no availability was found' do
        service.call

        expect(logger).to have_received(:info).with(/no availability found/)
      end

      it 'does not send a Telegram notification' do
        expect(Telegram::ChatService).not_to receive(:new)

        service.call
      end
    end

    context 'when slots are available' do
      let(:slot_a) { double('slot', to_s: '2026-04-10 09:00', strftime: '09:00') }
      let(:slot_b) { double('slot', to_s: '2026-04-10 10:00', strftime: '10:00') }
      let(:avail)  { double('avail', slots: [slot_a, slot_b], date: Date.new(2026, 4, 10)) }
      let(:chat_service) { instance_double(Telegram::ChatService, deliver: nil) }

      before do
        allow(collection).to receive(:total).and_return(2)
        allow(collection).to receive(:slots).and_return([slot_a, slot_b])
        allow(collection).to receive(:each).and_yield(avail)
        allow(avail).to receive(:date).and_return(Date.new(2026, 4, 10))
        allow(Telegram::ChatService).to receive(:new).and_return(chat_service)
        allow(Telegram::ChatService).to receive(:build_inline_keyboard).and_return(nil)
      end

      context 'with no previous slots (first run)' do
        let(:previous_slots) { nil }

        it 'sends a notification' do
          service.call

          expect(chat_service).to have_received(:deliver)
        end

        it 'returns a slots_found result hash' do
          result = service.call

          expect(result).to include(watch_name: 'dentist_paris', total: 2)
          expect(result[:slots_by_date]).to contain_exactly('2026-04-10 09:00', '2026-04-10 10:00')
        end
      end

      context 'when slots are unchanged from previous run' do
        let(:previous_slots) { ['2026-04-10 09:00', '2026-04-10 10:00'] }

        it 'does not send a notification' do
          service.call

          expect(chat_service).not_to have_received(:deliver)
        end

        it 'logs that slots are unchanged' do
          service.call

          expect(logger).to have_received(:info).with(/unchanged/)
        end

        it 'still returns a result hash' do
          result = service.call

          expect(result).to include(watch_name: 'dentist_paris', total: 2)
        end
      end

      context 'when slots have changed from previous run' do
        let(:previous_slots) { ['2026-04-09 08:00'] }

        it 'sends a notification' do
          service.call

          expect(chat_service).to have_received(:deliver)
        end

        it 'logs that a notification was sent' do
          service.call

          expect(logger).to have_received(:info).with(/notification sent/)
        end
      end
    end

    context 'when first page is empty but more pages exist' do
      before do
        allow(collection).to receive(:more?).and_return(true)
        allow(collection).to receive(:load_next!)
      end

      it 'loads the next page' do
        service.call

        expect(collection).to have_received(:load_next!)
      end
    end

    context 'with start_date: "today"' do
      let(:params) { super().merge('start_date' => 'today') }

      it 'resolves to today\'s date' do
        expect(TocDoc::Availability).to receive(:where).with(hash_including(start_date: Date.today))

        service
      end
    end

    context 'with a specific start_date' do
      let(:params) { super().merge('start_date' => '2026-06-01') }

      it 'parses the date' do
        expect(TocDoc::Availability).to receive(:where).with(hash_including(start_date: Date.new(2026, 6, 1)))

        service
      end
    end
  end
end
