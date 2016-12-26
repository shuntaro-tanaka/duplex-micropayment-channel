class ChannelsController < ApplicationController

  require 'openassets'
  include Bitcoin::Util

#  before_filter :authenticate_user!
#  before_action :set_wallet, only: [:show, :edit, :update, :destroy]

  def index

    #1 鍵の準備
    bitcoin_pool_addr      = "mtBAeSAK8JbMsMzf7hUgrEbh1B2pSU23gV"

    client_key          = Bitcoin::Key.from_base58("cQbF9YdmXFJnuukUPBee2g8pHcfw1njociCi6NToLMgSJHUhSW2v")
    server_key          = Bitcoin::Key.from_base58("cQsAdCCqEhAMCTqcnmenZgR3CBw1GgQwJKQdiLEv8cUqjWZw1WsY")

    # client_address  = "n1afn4z8MfaVvr591KmJPiXifz1C7LUYTN"
    # server_address  = "mojsVMcNBJ53HuLHrg2mF7prRAgqboNEY4"

    #2 オープニングトランザクションの作成

    tx_fee          = 10000
    deposit_amount  = 100000000
    api.send_bitcoin(bitcoin_pool_addr, deposit_amount + tx_fee, client_key.addr, tx_fee)

    # from, amount, to, tx_fee を引数に、send_bitcoin
    p2sh_script, redeem_script =  Bitcoin::Script.to_p2sh_multisig_script(2, client_key.pub, server_key.pub)
    multisig_addr = Bitcoin::Script.new(p2sh_script).get_p2sh_address # "2MyDTig8RbZhQay7RYTgtxfa7Y6UfTGYQPz"
    opening_tx = api.send_bitcoin(client_key.addr, deposit_amount, multisig_addr, tx_fee, 'signed')
    # opening_tx.hash = "63a08b12a1f7099b30d25eaa433cbb1c707ca0a046a62a9fba8d0b79cf2c6793"

    #3 クライアント側 払い戻しトランザクションの作成、署名なし
    refund_tx = Bitcoin::Protocol::Tx.new

    opening_tx_vout  = 0
    block_height  = api.provider.getinfo['blocks'].to_i
    locktime      = block_height + 10

    refund_tx_in = Bitcoin::Protocol::TxIn.from_hex_hash(opening_tx.hash, opening_tx_vout)
    refund_tx.add_in(refund_tx_in)

    refund_tx_out = Bitcoin::Protocol::TxOut.value_to_address(amount - tx_fee, client_key.addr)
    refund_tx.add_out(refund_tx_out)

    refund_tx.in[0].sequence = [1234].pack("V")
    refund_tx.lock_time = locktime

    #4 サーバ側 払い戻し用トランザクション署名
    sig_hash = refund_tx.signature_hash_for_input(0, redeem_script)
    script_sig = Bitcoin::Script.to_p2sh_multisig_script_sig(redeem_script)

    script_sig_1 = Bitcoin::Script.add_sig_to_multisig_script_sig(server_key.sign(sig_hash), script_sig)
    refund_tx.in[0].script_sig = script_sig_1

    #5 クライアント側 署名の検証, 署名を追加, 並び替え
    refund_tx_copy = refund_tx

    script_sig_2 = Bitcoin::Script.add_sig_to_multisig_script_sig(client_key.sign(sig_hash), script_sig_1)
    script_sig_3 = Bitcoin::Script.sort_p2sh_multisig_signatures(script_sig_2, sig_hash)
    refund_tx_copy.in[0].script_sig = script_sig_3
    refund_tx_copy.verify_input_signature(0, opening_tx)

    if refund_tx_copy.verify_input_signature(0, opening_tx)
      refund_tx = refund_tx_copy
    end

    #6 オープニングトランザクションのブロードキャスト
    api.provider.send_transaction(opening_tx.to_payload.bth)
    # e5edce397b79186942284886936a3b17ddf5e0da6bec8a90cef9941f8a049c91

    #6' 払い戻し用トランザクションのブロードキャスト
    api.provider.send_transaction(refund_tx.to_payload.bth)
    # refund_tx.hash = "aa79431992f5532f430d12beb935a0a3fdde5f0581304f25b6c681303379da79"

    #7 コミットメントトランザクションの作成
    commitment_tx = Bitcoin::Protocol::Tx.new

    amount_to_server    = 30000000
    amount_to_client    = deposit_amount - amount_to_server - tx_fee

    commitment_tx_in = Bitcoin::Protocol::TxIn.from_hex_hash(opening_tx.hash, opening_tx_vout)
    commitment_tx.add_in(refund_tx_in)

    commitment_tx_out_1 = Bitcoin::Protocol::TxOut.value_to_address(amount_to_server, server_key.addr)
    commitment_tx_out_2 = Bitcoin::Protocol::TxOut.value_to_address(amount_to_client, client_key.addr)
    commitment_tx.add_out(commitment_tx_out_1)
    commitment_tx.add_out(commitment_tx_out_2)

    #クライアント側 コミットメントトランザクションに署名
    commitment_sig_hash = commitment_tx.signature_hash_for_input(0, redeem_script)
    commitment_script_sig = Bitcoin::Script.to_p2sh_multisig_script_sig(redeem_script)

    script_sig_A = Bitcoin::Script.add_sig_to_multisig_script_sig(client_key.sign(commitment_sig_hash), commitment_script_sig)
    commitment_tx.in[0].script_sig = script_sig_A

    #8 サーバ側 金額と署名を検証、署名を追加
    commitment_tx_copy = commitment_tx

    script_sig_B = Bitcoin::Script.add_sig_to_multisig_script_sig(server_key.sign(commitment_sig_hash), script_sig_A)
    script_sig_C = Bitcoin::Script.sort_p2sh_multisig_signatures(script_sig_B, commitment_sig_hash)
    commitment_tx_copy.in[0].script_sig = script_sig_C
    commitment_tx_copy.verify_input_signature(0, opening_tx)

    if commitment_tx_copy.verify_input_signature(0, opening_tx)
      commitment_tx = commitment_tx_copy
    end

    #9 コミットメントトランザクションのブロードキャスト
    api.provider.send_transaction(commitment_tx.to_payload.bth)
    # "a7e6684476157df313c9f10f8a06507683ca501b17718e52803f1cca49f27277"

  end

  def oa_api
    OpenAssets::Api.new(oa_config[:bitcoin])
  end

  def oa_config
    YAML.load_file(config_path).deep_symbolize_keys
  end

  def config_path
    "#{Rails.root}/config/openassets.yml"
  end


end
