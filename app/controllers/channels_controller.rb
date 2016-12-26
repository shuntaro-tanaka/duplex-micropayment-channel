class ChannelsController < ApplicationController

  require 'openassets'
  include Bitcoin::Util
  include Concerns::OpenAssetsWrapper

=begin

require 'openassets'

api = OpenAssets::Api.new({:network => 'testnet',
                           :provider => 'bitcoind', :cache => 'testnet.db',
                           :dust_limit => 600, :default_fees => 10000, :min_confirmation => 1, :max_confirmation => 9999999,
                           :rpc => {:user => 'xxx', :password => 'xxx', :schema => 'http', :port => 28332, :host => 'localhost', :timeout => 60, :open_timeout => 60}})

=end

  def index

    #1 鍵の準備
    alice_addr  = api.provider.getnewaddress('Alice') # motEpRaRrtJ7UCL4HwWDXhBfNJYUJYGFUk
    bob_addr    = api.provider.getnewaddress('Bob')   # mmnfjAf2Zq9D5JuChc9tgDBn54VPTdsKx6

    alice_key   = Bitcoin::Key.from_base58(api.provider.dumpprivkey(alice_addr))
    bob_key     = Bitcoin::Key.from_base58(api.provider.dumpprivkey(bob_addr))

    alice_witness_addr  = api.provider.addwitnessaddress(alice_key.addr)  # "2NAPcrgmTcZDgBBGgY8aU1unhRWYeKFVEwL"
    bob_witness_addr    = api.provider.addwitnessaddress(bob_key.addr)    # "2NCrYCt9xz3wbq4sJxseHH9NzYtRGjmjJua"



    #2 オープニングトランザクションの作成

    #2-1-1 ビットコインの準備 P2WPKH nested in BIP16 P2SH に送付
    tx_fee          = 10000
    deposit_amount  = 100000000
    bitcoin_pool_addr      = "mtBAeSAK8JbMsMzf7hUgrEbh1B2pSU23gV"

    api.send_bitcoin(bitcoin_pool_addr, deposit_amount + tx_fee, alice_witness_addr, tx_fee)
    api.send_bitcoin(bitcoin_pool_addr, deposit_amount + tx_fee, bob_witness_addr, tx_fee)

    # alice
    # hash    c5dd144b13dec4d1c86416e409b8bb9ffb6e6f165eb9f9c8cc854eac00fae38c
    # payload 010000000100036d2225e412a6fffa02189c7a9d6a4509ccb92c0396cf5ec29acbc18f9e1d0000000048473044022009695c906d466aad9090f8304fe74025127b77b923614e18eb38df4f85a5b91c02202441a99c217705e6de99654c4a0fe3f41361482d4422eb39cdda2c5d00fece3f01ffffffff02e0c20f24010000001976a9148adba05a0e817b8f677850f99aef47947e82bd7688ac1008f6050000000017a914bc108e5cedb4a998e5c67aa0f1b58ee75b1fe6408700000000

    # bob
    # hash    daa9226592033415cde7ea4c6277a4690285082ad66d6b959eb8350c8e9dc43a
    # bob     01000000010286d1cc02998ce04678bca1afa05f2503304b340d453128d4b9f2e9c5e8f6b50000000049483045022100b817da35bc657ff1ae155535231b738444fab48ff8ffdd473e26764a33aa2f190220112eb4b0ef5d9afe41b16662b6325bd27c5e0be6273ba51dcbec2b4412f3b87f01ffffffff02e0c20f24010000001976a9148adba05a0e817b8f677850f99aef47947e82bd7688ac1008f6050000000017a914d71827d07c462d4a5c11ed645d1cf292fbdf19628700000000

    #2-1-2 送られたものを自分に送り返す P2WPKH nested in BIP16 P2SH 宛に。（テスト）
    api.send_bitcoin(alice_witness_addr, deposit_amount, alice_witness_addr, tx_fee)

    # hash    34c0a3469950750983be5f263bb50bdc6523bc2d3ec88c6ee81f77cf63f88f68
    # payload 010000000001018ce3fa00ac4e85ccc8f9b95e166f6efb9fbbb809e41664c8d1c4de134b14ddc501000000171600145bc788e20d8e9b1b3fef63a3e6d7fccca8474ea3ffffffff0100e1f5050000000017a914bc108e5cedb4a998e5c67aa0f1b58ee75b1fe64087024730440220707067db07f5b8c707549988e430fdd4c706dd24da13ce9ef22b51b9b93046c90220212d969b498a773bb945364f55855b3c7cd1abac2c506f0246a8246f777868610121035ea91513326af241c1dff2e7c18fd46da52928000ada53a076b4e7a744d0d6e800000000


    #2-2 P2WSH nested in BIP16 P2SH に送付
    p2sh_script, redeem_script =  Bitcoin::Script.to_p2sh_multisig_script(2, alice_key.pub, bob_key.pub)
    multisig_addr = Bitcoin::Script.new(p2sh_script).get_p2sh_address

    opening_tx = api.send_bitcoin(alice_key.addr, deposit_amount, multisig_addr, tx_fee, 'unsigned')


    #2-2-1 P2WSHのマルチシグの作成
    # generate p2wsh multisig output script for given +args+.
    # returns the p2wsh output script, and the witness program needed to spend it.
    # see #to_witness_multisig_script for the witness program, and #to_p2sh_script for the p2sh script.
    def self.to_p2wsh_multisig_script(*args)
      witness_program = to_witness_multisig_script(*args)
      p2wsh_script = to_p2wsh_script(Bitcoin.hash160(witness_program.hth))
      return p2wsh_script, witness_program
    end

    # generate witness multisig output script for given +pubkeys+, expecting +m+ signatures.
    # returns a raw binary script of the form:
    #  <m> <pubkey> [<pubkey> ...] <n_pubkeys> OP_CHECKMULTISIG
    def self.to_witness_multisig_script(m, *pubkeys)
      raise "invalid m-of-n number" unless [m, pubkeys.size].all?{|i| (0..20).include?(i) }
      raise "invalid m-of-n number" if pubkeys.size < m
      pubs = pubkeys.map{|pk| pack_pushdata([pk].pack("H*")) }

      m = m > 16 ?              pack_pushdata([m].pack("C"))              : [80 + m.to_i].pack("C")
      n = pubkeys.size > 16 ?   pack_pushdata([pubkeys.size].pack("C"))   : [80 + pubs.size].pack("C")

      [ m, *pubs, n, [OP_CHECKMULTISIG].pack("C")].join
    end

    # generate p2wsh output script for given +p2wsh+ hash160. returns a raw binary script of the form:
    #  OP_HASH160 <p2wsh> OP_EQUAL
    def self.to_p2wsh_script(p2wsh)
      return nil  unless p2wsh
      # HASH160  length  hash  EQUAL
      [ ["a9",   "14",   p2wsh, "87"].join ].pack("H*")
    end




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

end
