# frozen_string_literal: true

require 'spec_helper'
require_relative '../../services/github_workflow_service'

RSpec.describe GithubWorkflowService do
  subject(:service) { described_class.new(repository: 'owner/repo', token: 'gh_token') }

  describe '#disable' do
    it 'issues a PUT to the workflow disable endpoint with auth headers' do
      stub = stub_request(:put, 'https://api.github.com/repos/owner/repo/actions/workflows/check.yml/disable')
             .with(headers: {
                     'Authorization' => 'Bearer gh_token',
                     'Accept' => 'application/vnd.github+json',
                     'X-GitHub-Api-Version' => '2022-11-28'
                   })
             .to_return(status: 204)

      service.disable('check.yml')

      expect(stub).to have_been_requested
    end
  end
end
