# frozen_string_literal: true

require 'httparty'

# Wraps the GitHub Actions workflow management API.
#
# Reads +GITHUB_REPOSITORY+ and +GITHUB_TOKEN+ from the environment, both of
# which are set automatically inside a GitHub Actions job (the token must be
# forwarded via +env:+ in the workflow step).
class GithubWorkflowService
  def initialize(repository: ENV.fetch('GITHUB_REPOSITORY'), token: ENV.fetch('GITHUB_TOKEN'))
    @repository = repository
    @token = token
  end

  # Disables a workflow so it no longer runs on its schedule.
  #
  # @param workflow_file [String] workflow filename, e.g. +"check.yml"+
  # @return [HTTParty::Response]
  def disable(workflow_file)
    HTTParty.put(
      "https://api.github.com/repos/#{@repository}/actions/workflows/#{workflow_file}/disable",
      headers: {
        'Authorization' => "Bearer #{@token}",
        'Accept' => 'application/vnd.github+json',
        'X-GitHub-Api-Version' => '2022-11-28'
      }
    )
  end
end
