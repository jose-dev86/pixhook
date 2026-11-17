class CreateMerchants < ActiveRecord::Migration[8.1]
  def change
    create_table :merchants do |t|
      t.string :name, null: false
      t.string :api_key_digest, null: false
      t.string :webhook_url
      t.string :webhook_secret, null: false
      t.timestamps
    end
    add_index :merchants, :api_key_digest, unique: true
  end
end
