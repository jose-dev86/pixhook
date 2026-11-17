class CreateWebhookEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :webhook_events do |t|
      t.references :merchant, null: false, foreign_key: true
      t.references :charge, null: false, foreign_key: true
      t.string :event_type, null: false
      t.jsonb :payload, null: false, default: {}
      t.string :status, null: false, default: "pending"
      t.integer :attempts, null: false, default: 0
      t.integer :last_response_code
      t.text :last_error
      t.datetime :delivered_at
      t.timestamps
    end
    add_index :webhook_events, [ :status, :created_at ]
    add_check_constraint :webhook_events, "status IN ('pending','delivered','dead')", name: "webhook_events_status_valid"
  end
end
