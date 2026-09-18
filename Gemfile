# frozen_string_literal: true

source 'https://rubygems.org'

gem 'httparty'
# Alwaysdata's Ruby 3.3 includes this version; its free plan cannot compile native gems.
gem 'bigdecimal', '3.1.5'
# HTTParty 0.24.2 passes the quirks_mode option removed by JSON 3.
gem 'json', '2.7.2'
gem 'toc_doc'

group :development do
  gem 'irb'

  gem 'byebug'
  gem 'dotenv'
  gem 'rubocop'
end

group :test do
  gem 'rspec'
  gem 'webmock'
end
