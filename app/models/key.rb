class Key < ActiveRecord::Base

  include Bitcoin::Util

  #  before_create :generate_and_set

  def generate_and_set
    key = Bitcoin::Key.generate
    Key.pubkey  = key.pubkey
    Key.privkey = key.privkey
  end

end
