class DashboardController < ApplicationController
  def show
    return unless demo_merchant

    charges = demo_merchant.charges
    events = demo_merchant.webhook_events

    @received_cents = charges.paid.sum(:amount_cents)
    @paid_count = charges.paid.count
    @pending_cents = charges.pending.sum(:amount_cents)
    @pending_count = charges.pending.count
    @events_total = events.count
    @events_delivered = events.delivered.count
    @dead_events = events.dead.includes(:charge).recent_first.limit(5)
    @dead_count = events.dead.count
    @recent_charges = charges.recent_first.includes(:webhook_events).limit(6)
  end
end
