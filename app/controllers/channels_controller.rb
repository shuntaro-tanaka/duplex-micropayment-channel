class ChannelsController < ApplicationController

  require 'openassets'
  include Bitcoin::Util
  include Concerns::OpenAssetsWrapper

  def index

    #1 鍵の準備

    alice_addr  = oa_api.provider.getnewaddress('Alice')
    bob_addr    = oa_api.provider.getnewaddress('Bob')

    alice_key   = Bitcoin::Key.from_base58(oa_api.provider.dumpprivkey(alice_addr))
    bob_key     = Bitcoin::Key.from_base58(oa_api.provider.dumpprivkey(bob_addr))

    alice_20bytes_hash = hash160(alice_key.pub)
    bob_20bytes_hash = hash160(bob_key.pub)
    # alice_witness_addr  = oa_api.provider.addwitnessaddress(alice_key.addr)
    # bob_witness_addr    = oa_api.provider.addwitnessaddress(bob_key.addr)

    tx_fee          = 100000
    deposit_amount  = 2499900000

    #コインベース
    input_tx_hash_alice  = "eaebd066a1354039022a21c476cb0dbc131d0dce20a759c35dc9433097d371ff"
    input_tx_hash_bob = "a8922146407b9a7b940db52502843b3d59499bd959830e42dd5a5b8a3c0f51ff"
    #input_tx_hash_alice = "579e6e73bbb0f3e8cb7679f08814a29a1aaee9ca63e921187c538875fa0bd8fe"
    #input_tx_hash_bob = "b92d39f50788e099659b3902563d0e70110abc0b8fe41adc2695437477bc5dfe"
    #input_tx_hash_alice = "2a1bf38dd6ce69d77e7f5f01659a60fb3d754d0e218ca883e419946a2cdb43fb"
    #input_tx_hash_bob = "f2a20a35d074244bf6412028ab0cfaff30ff5ef4268f04d10f708bbc821a65f5"

    #2 オープニングトランザクションの作成

    alice_tx = segwit_send_bitcoin(input_tx_hash_alice, deposit_amount, alice_20bytes_hash, mode = 'broadcast', segwit = false)
    bob_tx   = segwit_send_bitcoin(input_tx_hash_bob, deposit_amount, bob_20bytes_hash, mode = 'broadcast', segwit = false)

    oa_api.provider.generate(1)

    #テスト 自分に送り返す。
    # resend_amount   = deposit_amount - 100000
    # alice_resend_tx = segwit_send_bitcoin(alice_tx.hash, resend_amount, alice_20bytes_hash, mode = 'broadcast', segwit = true)

    #2-2-2 オープニングトランザクションの作成
    # input に alice, bob のトランザクションを指定
    alice_tx_in = Bitcoin::Protocol::TxIn.from_hex_hash(alice_tx.hash, tx_vout = 0)
    bob_tx_in   = Bitcoin::Protocol::TxIn.from_hex_hash(bob_tx.hash, tx_vout = 0)

    # output に p2wsh 宛の outputを指定
    p2wsh_script, witness_program =  to_p2wsh_multisig_script(2, alice_key.pub, bob_key.pub)
    opening_tx_out = Bitcoin::Protocol::TxOut.new(deposit_amount * 2 - tx_fee, p2wsh_script)

    # tx に投入
    opening_tx  = Bitcoin::Protocol::Tx.new
    opening_tx.add_in(alice_tx_in)
    opening_tx.add_in(bob_tx_in)
    opening_tx.add_out(opening_tx_out)

    p '------- opening tx ------- '
    p opening_tx
    p opening_tx.hash
    p opening_tx.to_payload
    p opening_tx.to_payload.bth
    p '------- opening tx ------- '

    # tx に署名
    segwit_process_transaction(opening_tx, mode = 'broadcast', segwit = true)

    p stop

    # 01000000000102295dafd9d3e20a0bbc06a3f1d172961c83924df409854639fea37c0a1f934d730000000000ffffffff7d6d0920bad12db99e457b0e25a26fb5cf5ceef3c439aa4fdbfb3296aee403690000000000ffffffff01205e012a01000000220020c02406bd84639694020eaa4e981c3f2b894ef5ae1cc30631453d56798059de700247304402205d514aebebe7e44c251dc83345a8967470feec8aaa3716a04d3d4f62c4673cf1022059936732dbeb370eb29324b3c243077ed5b43efff583537500dc128a1a7926630121029dca8830dcf558fb6954c27af575496c04f15f7d18b87fc1d102ecad7257170c02473044022004e2ae64c12b02cfdcef26336bf17a8ee74476b60865547ccba46bb5b99460f302202ba97ba8f1fe25bdd3660e5af71130585480642c9961bda86ad9f59f374c9c2c012102da3445ae3f973e26d080cc835fd337fdbf75f30886805e19ec634048aeeaf21700000000
    # hash     "e6d28b98fe2fe2f8e781148be8fc57df99df643734dd23284a3acf40efdaadac"

    #テスト マルチシグに署名、マルチシグ宛にに送り返す。
    malti_resend_amount   = deposit_amount * 2 - tx_fee * 2
    malti_resend_tx = segwit_send_bitcoin(alice_tx.hash, deposit_amount * 2 - tx_fee *2 , p2wsh_script, mode = 'broadcast', segwit = true)


  end

=begin
     #3 クライアント側 払い戻しトランザクションの作成、署名なし
    refund_tx = Bitcoin::Protocol::Tx.new

    opening_tx_vout  = 0
    block_height  = oa_api.provider.getinfo['blocks'].to_i
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
    oa_api.provider.send_transaction(opening_tx.to_payload.bth)
    # e5edce397b79186942284886936a3b17ddf5e0da6bec8a90cef9941f8a049c91

    #6' 払い戻し用トランザクションのブロードキャスト
    oa_api.provider.send_transaction(refund_tx.to_payload.bth)
    # refund_tx.hash = "aa79431992f5532f430d12beb935a0a3fdde5f0581304f25b6c681303379da79"

    #7 コミットメントトランザクションの作成
    commitment_tx = Bitcoin::Protocol::Tx.new

    amount_to_server    = 30000000
    amount_to_client    = deposit_amount - amount_to_server - tx_fee

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
    oa_api.provider.send_transaction(commitment_tx.to_payload.bth)
    # "a7e6684476157df313c9f10f8a06507683ca501b17718e52803f1cca49f27277"
=end #単方向

  def segwit_send_bitcoin(input_tx_hash, amount, to, mode = 'broadcast', segwit)
    # p2pkh宛Txの input
    tx_in  = Bitcoin::Protocol::TxIn.from_hex_hash(input_tx_hash, tx_vout = 0)

    # p2Wpkh nested in p2sh 宛の output
    tx_out = Bitcoin::Protocol::TxOut.new(amount, to_p2wpkh_script(to))

    # tx に投入
    tx  = Bitcoin::Protocol::Tx.new
    tx.add_in(tx_in)
    tx.add_out(tx_out)

    # tx に署名
    segwit_process_transaction(tx, mode, segwit = true)
  end


  def segwit_process_transaction(tx, mode, segwit)
    if mode == 'broadcast' || mode == 'signed'
      signed_tx = oa_api.provider.sign_transaction(tx.to_payload.bth)
      if mode == 'broadcast'
        if segwit
          puts oa_api.provider.send_transaction(signed_tx.to_witness_payload.bth)
        else
          puts oa_api.provider.send_transaction(signed_tx.to_payload.bth)
        end
      end
      signed_tx
    else
      tx
    end
  end

  def to_p2wsh_multisig_script(*args)
    witness_program = Bitcoin::Script.to_multisig_script(*args)
    p2wsh_script = to_p2wsh_script(Bitcoin.sha256(witness_program.hth))
    return p2wsh_script, witness_program
  end

  def to_p2wpkh_script(p2wpkh)
    # 0 length 32bytes-hash
    [ ["00", "14", p2wpkh ].join ].pack("H*")
  end

  def to_p2wsh_script(p2wsh)
    # 0 length 32bytes-hash
    [ ["00", "20", p2wsh ].join ].pack("H*")
  end

end