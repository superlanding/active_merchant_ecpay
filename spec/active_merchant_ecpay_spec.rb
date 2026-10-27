require "spec_helper"

RSpec.describe ActiveMerchantEcpay do
  it "has a version number" do
    expect(ActiveMerchantEcpay::VERSION).not_to be nil
  end

  it "has a semantic version string" do
    expect(ActiveMerchantEcpay::VERSION).to match(/\A\d+\.\d+\.\d+/)
  end

  it "includes the payment_service_for view helper into ActionView::Base" do
    expect(ActionView::Base.ancestors).to include(OffsitePayments::ActionViewHelper)
  end

  it "autoloads the Ecpay integration" do
    expect(OffsitePayments::Integrations::Ecpay).to be_a(Module)
    expect(OffsitePayments.integration("Ecpay")).to eq(OffsitePayments::Integrations::Ecpay)
  end
end
