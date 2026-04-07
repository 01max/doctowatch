# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require_relative '../../services/report_writer'

RSpec.describe ReportWriter do
  describe '.write' do
    let(:tmp_dir) { Dir.mktmpdir }
    let(:report_path) { File.join(tmp_dir, 'report.json') }

    before do
      stub_const('ReportWriter::REPORT_PATH', report_path)
    end

    after { FileUtils.rm_rf(tmp_dir) }

    let(:results) do
      [
        { watch_name: 'dentist', total: 2, slots_by_date: ['2026-04-10 09:00', '2026-04-10 10:00'] },
        { watch_name: 'gp', total: 0, slots_by_date: [] },
        { watch_name: 'cardio', error: 'HTTP 403' }
      ]
    end

    it 'creates the report file' do
      described_class.write(results)

      expect(File).to exist(report_path)
    end

    it 'writes valid JSON' do
      described_class.write(results)

      expect { JSON.parse(File.read(report_path)) }.not_to raise_error
    end

    it 'includes a generated_at timestamp' do
      described_class.write(results)

      data = JSON.parse(File.read(report_path))
      expect(data['generated_at']).to match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z/)
    end

    it 'serializes slots_found watches correctly' do
      described_class.write(results)

      watch = JSON.parse(File.read(report_path))['watches'].first
      expect(watch).to include('watch' => 'dentist', 'status' => 'slots_found', 'total' => 2)
      expect(watch['slots_by_date']).to eq(['2026-04-10 09:00', '2026-04-10 10:00'])
    end

    it 'serializes no_slots watches correctly' do
      described_class.write(results)

      watch = JSON.parse(File.read(report_path))['watches'][1]
      expect(watch).to eq('watch' => 'gp', 'status' => 'no_slots')
    end

    it 'serializes error watches correctly' do
      described_class.write(results)

      watch = JSON.parse(File.read(report_path))['watches'].last
      expect(watch).to eq('watch' => 'cardio', 'status' => 'error', 'error' => 'HTTP 403')
    end

    it 'creates the tmp directory if it does not exist' do
      nested_path = File.join(tmp_dir, 'nested', 'report.json')
      stub_const('ReportWriter::REPORT_PATH', nested_path)

      expect { described_class.write([]) }.not_to raise_error
      expect(File).to exist(nested_path)
    end
  end
end
