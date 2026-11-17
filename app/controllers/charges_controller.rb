class ChargesController < ApplicationController
  before_action :require_demo_merchant!
  before_action :set_charge, only: %i[show pay refund]

  rate_limit to: 20, within: 1.minute, only: :create, with: -> { redirect_to new_charge_path, alert: t("charges.flash.invalid") }

  def index
    @status = params[:status].presence_in(Charge.statuses.keys)
    @counts = demo_merchant.charges.group(:status).count
    @charges = demo_merchant.charges.with_status(@status).recent_first.includes(:webhook_events).limit(50)
  end

  def show
    @events = @charge.webhook_events.order(:id)
  end

  def new
    @idempotency_key = SecureRandom.uuid
  end

  def create
    result = CreateCharge.call(merchant: demo_merchant, idempotency_key: params[:idempotency_key], params: charge_params)

    if result.success?
      redirect_to charge_path(result.charge), notice: t(result.created ? "charges.flash.created" : "charges.flash.replayed")
    else
      @idempotency_key = SecureRandom.uuid
      @errors = result.charge&.errors&.full_messages || [ t("charges.flash.invalid") ]
      render :new, status: :unprocessable_content
    end
  end

  def pay
    transition(:pay!, "charges.flash.paid")
  end

  def refund
    transition(:refund!, "charges.flash.refunded")
  end

  private

  def set_charge
    @charge = demo_merchant.charges.find(params[:id])
  end

  def transition(action, notice)
    @charge.public_send(action)
    redirect_back_or_to charge_path(@charge), notice: t(notice)
  rescue Charge::InvalidTransition
    status = Charge.human_attribute_name("statuses.#{@charge.reload.status}").downcase
    redirect_back_or_to charge_path(@charge), alert: t("charges.flash.invalid_transition", status:)
  end

  # The form takes reais ("49,90"); the domain stores cents.
  def charge_params
    raw = params.dig(:charge, :amount).to_s.strip
    amount = raw.include?(",") ? raw.delete(".").tr(",", ".") : raw
    cents = amount.match?(/\A\d+(\.\d{1,2})?\z/) ? (BigDecimal(amount) * 100).to_i : nil
    { amount_cents: cents, description: params.dig(:charge, :description).to_s.strip.presence }
  end
end
