class CreateChannels < ActiveRecord::Migration
  def change
    create_table :channels do |t|

      t.string :channel_id,       null: false, unique: true
      t.string :key_id,           null: false
      t.string :pubkey,           null: false
      t.string :privkey,          null: false
      t.datetime :created_at,     null: false
      t.datetime :updated_at,     null: false
      t.string :opening_tx_id,    null: false
      t.string :refund_tx_id,     null: false
      t.string :commitment_tx_id, null: false

    end
  end
end
