class WebhookEventsController < ApplicationController
  before_action :require_demo_merchant!

  def index
    @events = demo_merchant.webhook_events.includes(:charge).recent_first.limit(100)
  end

  def redeliver
    demo_merchant.webhook_events.find(params[:id]).redeliver!
    redirect_back_or_to webhook_events_path, notice: t("charges.flash.redelivered")
  end
end
