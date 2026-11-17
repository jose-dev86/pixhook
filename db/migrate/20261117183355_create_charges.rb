class CreateCharges < ActiveRecord::Migration[8.1]
  def change
    create_table :charges do |t|
      t.references :merchant, null: false, foreign_key: true
      t.string :txid, null: false
      t.integer :amount_cents, null: false
      t.string :description
      t.string :status, null: false, default: "pending"
      t.string :idempotency_key, null: false
      t.string :request_fingerprint, null: false
      t.datetime :expires_at, null: false
      t.datetime :paid_at
      t.datetime :refunded_at
      t.timestamps
    end
    add_index :charges, :txid, unique: true
    add_index :charges, [ :merchant_id, :idempotency_key ], unique: true
    add_index :charges, [ :merchant_id, :created_at ]
    add_check_constraint :charges, "amount_cents > 0", name: "charges_amount_positive"
    add_check_constraint :charges, "status IN ('pending','paid','expired','refunded')", name: "charges_status_valid"
  end
end
