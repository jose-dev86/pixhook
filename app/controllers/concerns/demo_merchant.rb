# The panel is a public demo: every page works on the first (demo) merchant.
module DemoMerchant
  extend ActiveSupport::Concern

  included do
    helper_method :demo_merchant
  end

  private

  def demo_merchant
    @demo_merchant ||= Merchant.order(:id).first
  end

  def require_demo_merchant!
    redirect_to root_path unless demo_merchant
  end
end
