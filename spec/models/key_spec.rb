require 'rails_helper'

RSpec.describe Key, type: :model do

  require 'openassets'
  include Bitcoin::Util
  include Concerns::OpenAssetsWrapper

  OP_0           = 0
  OPCODES = Hash[*constants.grep(/^OP_/).map{|i| [const_get(i), i.to_s] }.flatten]
  SIGHASH_TYPE = { all: 1, none: 2, single: 3, anyonecanpay: 128 }


  def to_p2wsh_multisig_script(*args)
    witness_script = Bitcoin::Script.to_multisig_script(*args)
    p2wsh_script = to_p2wsh_script(Bitcoin.sha256(witness_script.hth))
    return p2wsh_script, witness_script
  end

  def add_sig_to_multisig_witness(sig, hash_type = SIGHASH_TYPE[:all])
    signature = sig + [hash_type].pack("C*")
    signature
  end

  def to_p2wpkh_script(p2wpkh)
    # 0 length 32bytes-hash
    [ ["00", "14", p2wpkh ].join ].pack("H*")
  end

  def to_p2wsh_script(p2wsh)
    # 0 length 32bytes-hash
    [ ["00", "20", p2wsh ].join ].pack("H*")
  end

  def is_witness?(script)
    is_witness_v0_keyhash?(script) || is_witness_v0_scripthash?(script)
  end

  # see https://github.com/bitcoin/bips/blob/master/bip-0141.mediawiki#Witness_program
  def is_witness_v0_keyhash?(script)
    script.chunks.length == 2 &&script.chunks[0] == 0 && script.chunks[1].is_a?(String) && script.chunks[1].bytesize == 20
  end

  # see https://github.com/bitcoin/bips/blob/master/bip-0141.mediawiki#Witness_program
  def is_witness_v0_scripthash?(script)
    script.chunks.length == 2 &&script.chunks[0] == 0 && script.chunks[1].is_a?(String) && script.chunks[1].bytesize == 32
  end





  def signature_hash_for_segwit_input(tx, input_idx, script_pubkey, prev_out_value, hash_type=nil, witness_script = nil)
    return "\x01".ljust(32, "\x00") if input_idx >= tx.in.size # ERROR: SignatureHash() : input_idx=%d out of range

    hash_type ||= SIGHASH_TYPE[:all]

    script = Bitcoin::Script.new(script_pubkey)
    raise "ScriptPubkey does not contain witness program." unless is_witness?(script)

    hash_prevouts = Digest::SHA256.digest(Digest::SHA256.digest(tx.in.map{|i| [i.prev_out_hash, i.prev_out_index].pack("a32V")}.join))
    hash_sequence = Digest::SHA256.digest(Digest::SHA256.digest(tx.in.map{|i|i.sequence}.join))
    outpoint = [tx.in[input_idx].prev_out_hash, tx.in[input_idx].prev_out_index].pack("a32V")
    amount = [prev_out_value].pack("Q")
    nsequence = tx.in[input_idx].sequence

    script_code = [["1976a914", script.get_hash160, "88ac"].join].pack("H*") if is_witness_v0_keyhash?(script)
    if is_witness_v0_scripthash?(script)
      raise "witness script does not match script pubkey" if to_p2wsh_script(Digest::SHA256.digest(witness_script).bth) != script_pubkey
      script_code = Bitcoin::Script.pack_pushdata(witness_script)
    end

    hash_outputs = Digest::SHA256.digest(Digest::SHA256.digest(tx.out.map{|o|o.to_payload}.join))

    case (hash_type & 0x1f)
      when SIGHASH_TYPE[:anyonecanpay]
        hash_prevouts = "\x00".ljust(32, "\x00")
        hash_sequence = "\x00".ljust(32, "\x00")
        hash_outputs = "\x00".ljust(32, "\x00")
      when SIGHASH_TYPE[:single]
        if input_idx >= @out.size
          hash_outputs = "\x00".ljust(32, "\x00")
        else
          hash_outputs = "\x00".ljust(32, "\x00")
        end
        hash_sequence = "\x00".ljust(32, "\x00")
      when SIGHASH_TYPE[:none]
        hash_sequence = "\x00".ljust(32, "\x00")
        hash_outputs = "\x00".ljust(32, "\x00")
    end

    buf = [ [tx.ver].pack("V"), hash_prevouts, hash_sequence, outpoint,
            script_code, amount, nsequence, hash_outputs, [tx.lock_time, hash_type].pack("VV")].join

    Digest::SHA256.digest( Digest::SHA256.digest( buf ) )

    #hashPrevouts
=begin
    if (hash_type & 0x1f) == SIGHASH_TYPE[:anyonecanpay]
      ss = ""
      (1..tx.in.size).each do |n|
        ss << tx.in[n].prev_out;
      end
      hash_prevouts = Digest::SHA256.digest(Digest::SHA256.digest(ss))
    else
      hash_prevouts = "".ljust(256, "\x00")
    end

    #hashSequence
    if (hash_type & 0x1f) != SIGHASH_TYPE[:anyonecanpay] && (hash_type & 0x1f) != SIGHASH_TYPE[:single] && (hash_type & 0x1f) != SIGHASH_TYPE[:none]
      ss = ""
      (1..tx.in.size).each do |n|
        ss << tx.in[n-1].sequence
      end
      hash_sequence = Digest::SHA256.digest(Digest::SHA256.digest(ss))
    else
      hash_sequence = "".ljust(256, "\x00")
    end

    #outpoint
    outpoint = tx.in[input_idx].prev_out

    #script_code_of_the_input
    script_code_of_the_input = [0].pack("C*")  #static_cast<const CScriptBase&>(scriptCode);

    #amount
    amount = tx.out[0].value

    #n_sequence
    n_sequence = tx.in[input_idx].sequence

    #hash_outputs
    if ((hash_type & 0x1f) != SIGHASH_TYPE[:single] && (hash_type & 0x1f) != SIGHASH_TYPE[:none])
      ss = []
      (1..tx.out.size).each do |n|
        ss << tx.out[n-1];
      end
      hash_outputs = Digest::SHA256.digest(Digest::SHA256.digest(ss))
    else ((hash_type & 0x1f) == SIGHASH_TYPE[:single] && input_idx < @out.size())
    ss = ""
    ss << @out[input_idx]
    hash_outputs = Digest::SHA256.digest(Digest::SHA256.digest(ss))
    end

    buf = [ [tx.ver].pack("V"), hash_prevouts, hash_sequence, outpoint, script_of_the_input, amount.pack("Q"), n_sequence.pack("V"), hash_outputs, [@lock_time, hash_type].pack("VV") ].join
    Digest::SHA256.digest( Digest::SHA256.digest( buf ) )
=end
  end

  def segwit_send_multisig_bitcoin(input_tx_hash, script_pubkey, prev_out_value, amount, to, mode = 'broadcast', segwit, alice_key, bob_key, witness_script)
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

    #署名 #ここのミスっぽい
    sig_hash   = signature_hash_for_segwit_input(tx, tx_vout, script_pubkey, prev_out_value, hash_type=nil, witness_script)
    alice_sig = add_sig_to_multisig_witness(alice_key.sign(sig_hash))
    bob_sig   = add_sig_to_multisig_witness(bob_key.sign(sig_hash))

    tx_in_witness = Bitcoin::Protocol::TxInWitness.new
    tx_in_witness.add_stack("")
    tx_in_witness.add_stack(alice_sig.bth)
    tx_in_witness.add_stack(bob_sig.bth)
    tx_in_witness.add_stack(witness_script.hth)
    tx.witness.add_witness(tx_in_witness)

    p '--- after sign tx ---'
    p tx
    p tx.hash
    p tx.to_witness_payload.bth
    p '--- after sign tx ---'

    if mode == 'broadcast'
      if segwit
        puts oa_api.provider.send_transaction(tx.to_witness_payload.bth)
      else
        puts oa_api.provider.send_transaction(tx.to_payload.bth)
      end
    end

  end

=begin
  it 'test_p2wpkh_sig' do
    alice_addr  = "mwkzBcRWNbKYG99JApFxfXWM28qNYrfCSS"
    bob_addr    = "mv4CoVBNarrehpzhpkF7MtpHuz3UGhMFKG"
    alice_key   = Bitcoin::Key.from_base58(oa_api.provider.dumpprivkey(alice_addr))
    bob_key     = Bitcoin::Key.from_base58(oa_api.provider.dumpprivkey(bob_addr))
    tx_in1_hash = "1981c721c37480539933ca865d81d6e8b3c4d4c88e2e4d732deea3fffd612c2d"
    tx_in2_hash = "a95bfb33882e0db61d253637b4300195737596e2ee428679eae512b87234cf9d"
    alice_20bytes_hash = hash160(alice_key.pub)
    alice_to = to_p2wpkh_script(alice_20bytes_hash)
    p2wsh_script, witness_script =  to_p2wsh_multisig_script(2, alice_key.pub, bob_key.pub)

    tx_fee          = 100000
    deposit_amount  = 4999900000
    amount = deposit_amount * 2 - tx_fee
    tx_vout = 0

    tx_in_1  = Bitcoin::Protocol::TxIn.from_hex_hash(tx_in1_hash, tx_vout)
    tx_out = Bitcoin::Protocol::TxOut.new(amount, p2wsh_script)

    opening_tx  = Bitcoin::Protocol::Tx.new
    opening_tx.add_in(tx_in_1)
    opening_tx.add_out(tx_out)

    #signed_tx = oa_api.provider.sign_transaction(opening_tx.to_payload.bth)
    sig_hash   = signature_hash_for_segwit_input(opening_tx, tx_vout, alice_to, hash_type=nil, witness_script)
    tx_in_witness = Bitcoin::Protocol::TxInWitness.new
    tx_in_witness = add_sig_to_multisig_witness(alice_key.sign(sig_hash), tx_in_witness)
    tx_in_witness.add_stack, alice_key.pub.bth)
    tx.witness.add_witness(tx_in_witness)

    p '--- after sign tx ---'
    p tx
    p tx.hash
    p tx.to_witness_payload.bth
    p '--- after sign tx ---'

    puts oa_api.provider.send_transaction(signed_tx.to_witness_payload.bth)

  end
=end


  it 'test_p2wsh_multisig' do
    alice_addr  = "mwkzBcRWNbKYG99JApFxfXWM28qNYrfCSS"
    bob_addr    = "mv4CoVBNarrehpzhpkF7MtpHuz3UGhMFKG"
    alice_key   = Bitcoin::Key.from_base58(oa_api.provider.dumpprivkey(alice_addr))
    bob_key     = Bitcoin::Key.from_base58(oa_api.provider.dumpprivkey(bob_addr))
    opening_tx_hash = "077ee6ba7616f5fb490fdb8990abe0cee6ce583e80986734069271601af7a5e1"
    p2wsh_script, witness_script =  to_p2wsh_multisig_script(2, alice_key.pub, bob_key.pub)

    #テスト マルチシグに署名、マルチシグ宛に送り返す。
    tx_fee          = 100000
    deposit_amount  = 4999900000
    prev_out_value = 9999700000
    malti_resend_amount   = deposit_amount * 2 - tx_fee * 2
    script_pubkey = p2wsh_script
    malti_resend_tx = segwit_send_multisig_bitcoin(opening_tx_hash, script_pubkey, prev_out_value, malti_resend_amount, p2wsh_script, mode = 'broadcast', segwit = true, alice_key, bob_key, witness_script)
  end

  #it 'test' do
  #  tx = Bitcoin::Protocol::Tx.new('010000000001013bab0a5d4e6f9806621bb866a15f04b964a0012d35f31f3a2636b60d52dcc55e0000000000ffffffff01e0834e020000000016001417345ec3003316b5a8be7b9e98cf9e9c1184058b00000000'.htb)
  #  puts tx
  #end

end
