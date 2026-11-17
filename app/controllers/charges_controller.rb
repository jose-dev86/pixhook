# Read-only panel for the demo merchant, updated live with Turbo Streams.
class ChargesController < ApplicationController
  def index
    @merchant = Merchant.order(:id).first
    @charges = @merchant ? @merchant.charges.recent_first.includes(:webhook_events).limit(20) : Charge.none
  end

  def pay
    Charge.find(params[:id]).pay!
    redirect_to root_path, notice: "Pagamento simulado."
  rescue Charge::InvalidTransition => e
    redirect_to root_path, alert: e.message
  end
end
