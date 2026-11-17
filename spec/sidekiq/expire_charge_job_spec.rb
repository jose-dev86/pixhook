require "rails_helper"

RSpec.describe ExpireChargeJob, type: :job do
  let(:charge) { create(:charge) }

  it "expires a pending charge past its deadline" do
    charge.update!(expires_at: 1.minute.ago)
    described_class.new.perform(charge.id)
    expect(charge.reload).to be_expired
  end

  it "ignores a charge that was already paid" do
    charge.pay!
    travel 1.hour do
      described_class.new.perform(charge.id)
    end
    expect(charge.reload).to be_paid
  end

  it "ignores unknown ids" do
    expect { described_class.new.perform(-1) }.not_to raise_error
  end
end
