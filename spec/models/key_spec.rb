require 'rails_helper'

RSpec.describe Key, type: :model do

  it 'test' do
    tx = Bitcoin::Protocol::Tx.new('010000000001013bab0a5d4e6f9806621bb866a15f04b964a0012d35f31f3a2636b60d52dcc55e0000000000ffffffff01e0834e020000000016001417345ec3003316b5a8be7b9e98cf9e9c1184058b00000000'.htb)
    puts tx
  end


end
