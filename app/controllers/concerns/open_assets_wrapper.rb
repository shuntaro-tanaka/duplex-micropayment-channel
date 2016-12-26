module Concerns::OpenAssetsWrapper
  extend ActiveSupport::Concern
  include Concerns::OpenAssetsConfiguration
  include OpenAssets::Util

  def oa_api
    OpenAssets::Api.new(oa_config[:bitcoin])
  end

  def vote_asset_id
    oa_config[:vote][:asset_id]
  end

  # 指定されたasset_idの保有情報を取得する。
  def asset_holders(asset_id, address = nil)
    balance = balance_by_address(address)
    addresses = BitcoinAddress.all
    balance.select{|b| b['assets'].find{|a|a['asset_id'] == asset_id}}.map{|b|
      asset = b['assets'].find{|a|a['asset_id'] == asset_id}
      holder_address = addresses.find{|h|h.address == b['address']}
      {asset_id: asset['asset_id'],
       amount: asset['amount'],
       address: b['address'],
       holder: holder_address.nil? ? nil : holder_address.holder}
    }
  end

  # 指定されたアドレスが持つアセットの残高を取得する。
  def asset_balance(address)
    balance = balance_by_address(address)
    balance.select{|o|o['assets'].size > 0}.map{|o|o['assets']}.flatten
  end

  # Bitcoinアドレスを新規に発行する
  def create_new_address(account)
    oa_api.provider.getnewaddress(account)
  end

  # Bitcoinの残高を取得する（アセットのBitcoin残高は除外）
  def btc_balance(addresses = [])
    result = unspent_by_address(addresses)
    result.inject(BigDecimal(0)) {|sum , r|
      r['asset_id'].nil? ? sum + BigDecimal(r['amount']) : sum
    }
  end

  # アセットを発行する
  def issue_asset(from, amount, asset_def_url, to = nil)
    from_oa_address = address_to_oa_address(from)
    to_oa_address = to.nil? ? from_oa_address : address_to_oa_address(to)
    oa_api.issue_asset(from_oa_address, amount, "u=#{asset_def_url}", to_oa_address)
  end

  # アセットを送付する
  def send_asset(from, asset_id, amount, to, mode='broadcast')
    from_oa_address = address_to_oa_address(from)
    to_oa_address = address_to_oa_address(to)
    oa_api.send_asset(from_oa_address, asset_id, amount, to_oa_address, 10000, mode)
  end

  # 指定されたtxidのトランザクションデータを取得する。
  def tx(txid)
    oa_api.provider.get_transaction(txid, 1)
  end

  # 指定されたtxidのトランザクションデータをBitcoin::Protocol::Txで取得する。
  def btc_tx(txid)
    decode_tx = oa_api.provider.get_transaction(txid)
    return nil if decode_tx.nil?
    Bitcoin::Protocol::Tx.new(decode_tx.htb)
  end

  # Open Asset Protocolでパースした出力を取得
  def coloring_outputs(txid)
    oa_api.get_outputs_from_txid(txid)
  end

  # 指定されたtxidの出力に含まれているMarkerOutputを取得する
  def marker_output(txid)
    outputs = oa_api.get_outputs_from_txid(txid, true)
    mo = outputs.find{|o|
      script = Bitcoin::Script.new([o['script']].pack("H*")).to_payload
      !OpenAssets::Protocol::MarkerOutput.parse_script(script).nil?
    }
    unless mo.nil?
      script = Bitcoin::Script.new([mo['script']].pack("H*")).to_payload
      OpenAssets::Protocol::MarkerOutput.deserialize_payload(OpenAssets::Protocol::MarkerOutput.parse_script(script))
    else
      nil
    end
  end

  # Open Asset Addressか判定
  def oa_address?(address)
    begin
      bitcoin_address?(oa_address_to_address(address))
    rescue ArgumentError => e
      false
    end
  end

  # Bitcoin Addresか判定
  def bitcoin_address?(address)
    valid_address?(address)
  end

  private
  def load_balance
    @balances ||= oa_api.get_balance
  end

  def balance_by_address(address)
    return load_balance if address.nil?
    load_balance.select{|b|b['address'] == address}
  end

  def load_unspent
    @unspent ||= oa_api.list_unspent
  end

  def unspent_by_address(addresses)
    load_unspent.select{|o|addresses.include?(o['address'])}
  end

end