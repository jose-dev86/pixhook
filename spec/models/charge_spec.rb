require "rails_helper"

RSpec.describe Charge, type: :model do
  subject(:charge) { create(:charge) }

  describe "validations" do
    it { is_expected.to validate_numericality_of(:amount_cents).only_integer.is_greater_than(0) }
    it { is_expected.to validate_length_of(:description).is_at_most(140) }

    it "enforces positive amount in the database too" do
      expect { charge.update_column(:amount_cents, 0) }.to raise_error(ActiveRecord::StatementInvalid, /charges_amount_positive/)
    end
  end

  describe "defaults" do
    it "assigns txid and a 30 minute expiration" do
      freeze_time do
        aggregate_failures do
          expect(charge.txid).to match(/\A[a-zA-Z0-9]{32}\z/)
          expect(charge.expires_at).to eq(30.minutes.from_now)
          expect(charge).to be_pending
        end
      end
    end

    it "schedules the expiration job at expires_at" do
      expect { charge }.to change(ExpireChargeJob.jobs, :size).by(1)
      expect(ExpireChargeJob.jobs.last["at"]).to be_within(1).of(charge.expires_at.to_f)
    end
  end

  describe "#pay!" do
    it "moves to paid and writes a charge.paid outbox event" do
      freeze_time do
        expect { charge.pay! }.to change { charge.webhook_events.count }.by(1)
        aggregate_failures do
          expect(charge.reload).to be_paid
          expect(charge.paid_at).to eq(Time.current)
          expect(charge.webhook_events.last.payload.dig("data", "status")).to eq("paid")
        end
      end
    end

    it "enqueues the webhook delivery only after commit" do
      expect { charge.pay! }.to change(WebhookDeliveryJob.jobs, :size).by(1)
    end

    it "refuses to pay twice" do
      charge.pay!
      expect { charge.pay! }.to raise_error(Charge::InvalidTransition, /from paid to paid/)
    end

    it "rolls back the state change when the outbox insert fails" do
      allow_any_instance_of(WebhookEvent).to receive(:save!).and_raise(ActiveRecord::RecordInvalid)
      expect { charge.pay! }.to raise_error(ActiveRecord::RecordInvalid)
      expect(charge.reload).to be_pending
    end
  end

  describe "#refund!" do
    it "refunds a paid charge" do
      charge.pay!
      charge.refund!
      expect(charge.reload).to be_refunded
    end

    it "does not refund a pending charge" do
      expect { charge.refund! }.to raise_error(Charge::InvalidTransition)
    end
  end

  describe "#due_for_expiration?" do
    it "is true only for pending charges past expires_at" do
      charge.update!(expires_at: 1.minute.ago)
      expect(charge.due_for_expiration?).to be true
    end

    it "is false before expires_at" do
      expect(charge.due_for_expiration?).to be false
    end
  end
end
