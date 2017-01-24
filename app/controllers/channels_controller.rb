class ChannelsController < ApplicationController

  require 'openassets'
  include Bitcoin::Util
  include Concerns::OpenAssetsWrapper

  def index

    #1 鍵、アドレス、コインの準備
    alice_addr  = "mwkzBcRWNbKYG99JApFxfXWM28qNYrfCSS" #oa_api.provider.getnewaddress('Alice')
    bob_addr    = "mv4CoVBNarrehpzhpkF7MtpHuz3UGhMFKG" #oa_api.provider.getnewaddress('Bob')

    alice_key   = Bitcoin::Key.from_base58(oa_api.provider.dumpprivkey(alice_addr))
    bob_key     = Bitcoin::Key.from_base58(oa_api.provider.dumpprivkey(bob_addr))

    alice_20bytes_hash = hash160(alice_key.pub)
    bob_20bytes_hash = hash160(bob_key.pub)

    tx_fee          = 100000
    deposit_amount  = 4999900000

    #コインベース
    #input_tx_hash_alice   = "237887d8c894a62b3537db5e1b67361e28753d6d45dbae1ef76acab68f441b4a"
    #input_tx_hash_bob     = "ab80159a49bcecfe0ac2caf09bfef1a32c5b68d1ba55d1cc96d12344e9615c50"
    #input_tx_hash_alice  = "1a9fb3a200edd9699e44843c6b03f8fd01a157d69a912e1e7885f20c9f7f1e6d"
    #input_tx_hash_bob    = "f72aef46372161a484d2ac9332e05aa748ec6e5bd30a29a10b700a57a38d346f"
    #input_tx_hash_alice  = "fe85dbd4c62a188b17129f4684fe41cf5264586ddb98ff85a6f0c55673e8666f"
    #input_tx_hash_bob    = "009f9a68db71f4d6431ecef76c06aa07a383a105cec61d56e3d4b90978c29a71"
    #input_tx_hash_alice  = "53f4983faaedeccd9a78183e6ae279a127c07c0a25ae2bc3c5d7f3a0cd80c272"
    #input_tx_hash_bob    = "ca759ae47340192a916f3a8a7792382c0e5b39c8365f4ea71f7794d4dea96e75"
    input_tx_hash_alice  = "93ac37f2b335a92163491953516ca666417180112f23b46cb03dc38ee015da77"
    input_tx_hash_bob    = "0333e9bda6d917d3d271dca1dfc9a12b098bbdf8c8560a901807ab780f4df57d"
    #input_tx_hash_alice  = "68c160ca079a25011b57a4c94d100eede19f8e90d8fcee03268a0add4a4fd77e"
    #input_tx_hash_bob    = "2e64d17b58eb0e667451c9a1f4372a516043b0b42f4b18c88222c2feb43d2d7f"
    #input_tx_hash_alice  = "c7449055f4f85c944cf47297dcef86f4b8fff22c968456ac787169f035281581"
    #input_tx_hash_bob    = "8f0ca910f5af2b4f06387354ce6dd999a3df25196ef1553f3ffcce2f2cb38081"
    #input_tx_hash_alice  = "d0e917319f9bf6f42685fadb1832a24471918a18e5151223b572cac5ceb1b482"
    #input_tx_hash_bob    = "c1a5035efafd68a337adeacbe4de587b1337dcf9a1a4a3c4abce67ef2a7ce984"
    #input_tx_hash_alice  = "c59c0e026eb1501364f36153b2cadbca6ea14ea67a50c7cc4eac98de16d68386"
    #input_tx_hash_bob    = "e950cdd92abeae155ba979b6a020466ec68f610a57e9f149bce28d6eb00a4188"
    #input_tx_hash_alice  = "c6ef2f682673ce8ebb24152c8b86aea7f8adf41e61dbeca828222cb3ee13238b"
    #input_tx_hash_bob    = "2d1a25be7936a4076168cb20120bdc4f1df6fe3de04e44131974f6f5fa7fb28c"
    #input_tx_hash_alice  = "6630c545ab48c33be7c884a3415e365972d5aabde907aec1a990fa9a605c0c8d"
    #input_tx_hash_bob    = "58c87e5d0a478065a0c38874027836104963330ecefa3c26a27c96b1ec3bab8f"

    #2 オープニングトランザクションの作成
    #alice_to  = Bitcoin::Script.to_hash160_script(hash160(alice_key.pub))
    #bob_to    = Bitcoin::Script.to_hash160_script(hash160(alice_key.pub))
    alice_to = to_p2wpkh_script(alice_20bytes_hash)
    bob_to   = to_p2wpkh_script(bob_20bytes_hash)

    alice_tx = segwit_send_bitcoin(input_tx_hash_alice, deposit_amount, alice_to, mode = 'broadcast', segwit = false)
    bob_tx   = segwit_send_bitcoin(input_tx_hash_bob, deposit_amount, bob_to, mode = 'broadcast', segwit = false)

    oa_api.provider.generate(1)


    ###TEST aliceのUTXOをaliceに送り返す。
    # resend_amount   = deposit_amount - 100000
    # alice_resend_tx = segwit_send_bitcoin(alice_tx.hash, resend_amount, alice_20bytes_hash, mode = 'broadcast', segwit = true)
    ###

    #p2sh_script, redeem_script =  Bitcoin::Script.to_p2sh_multisig_script(2, alice_key.pub, bob_key.pub)
    p2wsh_script, witness_program =  to_p2wsh_multisig_script(2, alice_key.pub, bob_key.pub)


    amount = deposit_amount * 2 - tx_fee
    #opening_tx = send_opening_tx(alice_tx.hash, bob_tx.hash, amount, p2sh_script, mode = 'broadcast', segwit = false)
    opening_tx = send_opening_tx(alice_tx.hash, bob_tx.hash, amount, p2wsh_script, mode = 'broadcast', segwit = true)

    p '--- opening tx ---'
    p opening_tx


    # 01000000000102295dafd9d3e20a0bbc06a3f1d172961c83924df409854639fea37c0a1f934d730000000000ffffffff7d6d0920bad12db99e457b0e25a26fb5cf5ceef3c439aa4fdbfb3296aee403690000000000ffffffff01205e012a01000000220020c02406bd84639694020eaa4e981c3f2b894ef5ae1cc30631453d56798059de700247304402205d514aebebe7e44c251dc83345a8967470feec8aaa3716a04d3d4f62c4673cf1022059936732dbeb370eb29324b3c243077ed5b43efff583537500dc128a1a7926630121029dca8830dcf558fb6954c27af575496c04f15f7d18b87fc1d102ecad7257170c02473044022004e2ae64c12b02cfdcef26336bf17a8ee74476b60865547ccba46bb5b99460f302202ba97ba8f1fe25bdd3660e5af71130585480642c9961bda86ad9f59f374c9c2c012102da3445ae3f973e26d080cc835fd337fdbf75f30886805e19ec634048aeeaf21700000000
    # hash     "e6d28b98fe2fe2f8e781148be8fc57df99df643734dd23284a3acf40efdaadac"

    p stop

    #テスト マルチシグに署名、マルチシグ宛に送り返す。
    malti_resend_amount   = deposit_amount * 2 - tx_fee * 2
    malti_resend_tx = segwit_send_multisig_bitcoin(opening_tx.hash, malti_resend_amount, p2wsh_script, mode = 'broadcast', segwit = true, alice_key, bob_key, witness_program)


    #2-2-2 オープニングトランザクションの作成
    # input に alice, bob のトランザクションを指定


  end




  def segwit_send_bitcoin(input_tx_hash, amount, to, mode = 'broadcast', segwit)
    tx_in  = Bitcoin::Protocol::TxIn.from_hex_hash(input_tx_hash, tx_vout = 0)
    tx_out = Bitcoin::Protocol::TxOut.new(amount, to)

    tx  = Bitcoin::Protocol::Tx.new
    tx.add_in(tx_in)
    tx.add_out(tx_out)

    p '--- before sign tx ---'
    p tx
    p tx.hash
    p tx.to_payload.bth
    p '--- before sign tx ---'

    segwit_process_transaction(tx, mode, segwit)

  end

  def send_opening_tx(input1_tx_hash, input2_tx_hash, amount, to, mode, segwit)
    tx_in_1  = Bitcoin::Protocol::TxIn.from_hex_hash(input1_tx_hash, tx_vout = 0)
    tx_in_2  = Bitcoin::Protocol::TxIn.from_hex_hash(input2_tx_hash, tx_vout = 0)

    tx_out = Bitcoin::Protocol::TxOut.new(amount, to)

    opening_tx  = Bitcoin::Protocol::Tx.new
    opening_tx.add_in(tx_in_1)
    opening_tx.add_in(tx_in_2)
    opening_tx.add_out(tx_out)

    segwit_process_transaction(opening_tx, mode, segwit)
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

  def segwit_send_multisig_bitcoin(input_tx_hash, amount, to, mode = 'broadcast', segwit, alice_key, bob_key, witness_program)
    tx_in  = Bitcoin::Protocol::TxIn.from_hex_hash(input_tx_hash, tx_vout = 0)
    tx_out = Bitcoin::Protocol::TxOut.new(amount, to)

    tx  = Bitcoin::Protocol::Tx.new
    tx.add_in(tx_in)
    tx.add_out(tx_out)

    p '--- before sign commitment tx ---'
    p tx
    p tx.hash
    p tx.to_payload.bth
    p '--- before sign commitment tx ---'

    #署名 #ここのミス。 マルチシグに署名ができない。
    sig_hash = tx.signature_hash_for_input(0, witness_program)
    witness = Bitcoin::Script.add_sig_to_multisig_script_sig(alice_key.sign(sig_hash), witness)
    witness = Bitcoin::Script.add_sig_to_multisig_script_sig(bob_key.sign(sig_hash), witness)
    witness = Bitcoin::Script.to_p2sh_multisig_script_sig(witness_program)




    tx.witness.add_witness(witness)

    p '--- after sign commitment tx ---'
    p tx
    p tx.hash
    p '--- after sign commitment tx ---'

    if mode == 'broadcast'
      if segwit
        puts oa_api.provider.send_transaction(tx.to_witness_payload.bth)
      else
        puts oa_api.provider.send_transaction(tx.to_payload.bth)
      end
    end

    return tx

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