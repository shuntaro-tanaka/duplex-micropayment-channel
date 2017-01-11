module Concerns::OpenAssetsConfiguration
  extend ActiveSupport::Concern

  def oa_config
    YAML.load_file(config_path).deep_symbolize_keys
  end

  def testnet?
    oa_config[:bitcoin][:network] == 'testnet'
  end

  private
  def config_path
    "#{Rails.root}/config/openassets.yml"
  end

end