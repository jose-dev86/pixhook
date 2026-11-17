# Scheduled for the charge's expires_at. Safe to run more than once.
class ExpireChargeJob
  include Sidekiq::Job

  sidekiq_options queue: "default", retry: 3

  def perform(charge_id)
    charge = Charge.find_by(id: charge_id)
    return unless charge&.due_for_expiration?

    charge.expire!
  rescue Charge::InvalidTransition
    # Paid between the check and the lock: nothing to expire.
  end
end
