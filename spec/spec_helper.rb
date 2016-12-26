# $LOAD_PATH.unshift File.expand_path('../lib', __FILE__)
require 'rubygems'
require 'openassets'
require 'json'

RSpec.configure do |config|

  config.before(:each) do |example|
    if example.metadata[:network] == :testnet
      Bitcoin.network = :testnet3
    else
      Bitcoin.network = :bitcoin
    end
  end

  # 作成時
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end
end