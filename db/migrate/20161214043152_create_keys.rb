class CreateKeys < ActiveRecord::Migration
  def change
    create_table :keys do |t|
      t.string    :key_id,    null: false, unique: true
      t.string    :pubkey,    null: false
      t.string    :privkey,   null: false
      t.datetime  :create_at, null: false
      t.datetime  :update_at
    end
  end
end