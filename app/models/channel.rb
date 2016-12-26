class Channel < ActiveRecord::Base

  has_one :key


  def send_pubkey

    # save pubkey from client

    #    @client_key = Key.new
    #    @client_key.pubkey


    #
    #  private_key = Bitcoin::Key.from_base58(dumpprivkeyで取得した秘密鍵)
    #  public_key = private_key.pub
    #############
  end

  def set_original_address
    wishing_address = 'mm' + oa_config[:vote][:project_name] + self.id.to_s
    wishing_address = wishing_address[0..33]
    wishing_address.gsub!('O', 'o')
    wishing_address.gsub!('0', 'o')
    wishing_address.gsub!('I', '1')
    wishing_address.gsub!('l', '1')
    original_address = create_original_address(wishing_address)
    self.wallet.address = original_address
    self.wallet.save
    oa_api.provider.import_address(original_address)
  end
end
