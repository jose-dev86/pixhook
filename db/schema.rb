# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_11_17_183356) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "charges", force: :cascade do |t|
    t.bigint "merchant_id", null: false
    t.string "txid", null: false
    t.integer "amount_cents", null: false
    t.string "description"
    t.string "status", default: "pending", null: false
    t.string "idempotency_key", null: false
    t.string "request_fingerprint", null: false
    t.datetime "expires_at", null: false
    t.datetime "paid_at"
    t.datetime "refunded_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["merchant_id", "created_at"], name: "index_charges_on_merchant_id_and_created_at"
    t.index ["merchant_id", "idempotency_key"], name: "index_charges_on_merchant_id_and_idempotency_key", unique: true
    t.index ["merchant_id"], name: "index_charges_on_merchant_id"
    t.index ["txid"], name: "index_charges_on_txid", unique: true
    t.check_constraint "amount_cents > 0", name: "charges_amount_positive"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying, 'paid'::character varying, 'expired'::character varying, 'refunded'::character varying]::text[])", name: "charges_status_valid"
  end

  create_table "merchants", force: :cascade do |t|
    t.string "name", null: false
    t.string "api_key_digest", null: false
    t.string "webhook_url"
    t.string "webhook_secret", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["api_key_digest"], name: "index_merchants_on_api_key_digest", unique: true
  end

  create_table "webhook_events", force: :cascade do |t|
    t.bigint "merchant_id", null: false
    t.bigint "charge_id", null: false
    t.string "event_type", null: false
    t.jsonb "payload", default: {}, null: false
    t.string "status", default: "pending", null: false
    t.integer "attempts", default: 0, null: false
    t.integer "last_response_code"
    t.text "last_error"
    t.datetime "delivered_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["charge_id"], name: "index_webhook_events_on_charge_id"
    t.index ["merchant_id"], name: "index_webhook_events_on_merchant_id"
    t.index ["status", "created_at"], name: "index_webhook_events_on_status_and_created_at"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying, 'delivered'::character varying, 'dead'::character varying]::text[])", name: "webhook_events_status_valid"
  end

  add_foreign_key "charges", "merchants"
  add_foreign_key "webhook_events", "charges"
  add_foreign_key "webhook_events", "merchants"
end
