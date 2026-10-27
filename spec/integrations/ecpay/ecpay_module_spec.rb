require "spec_helper"

RSpec.describe OffsitePayments::Integrations::Ecpay do
  let(:ecpay) { described_class }

  describe ".service_url" do
    it "uses the production endpoint in production mode" do
      ActiveMerchant::Billing::Base.mode = :production
      expect(ecpay.service_url).to eq("https://payment.ecpay.com.tw/Cashier/AioCheckOut/V5")
    end

    it "uses the stage endpoint in development and test mode" do
      %i[development test].each do |mode|
        ActiveMerchant::Billing::Base.mode = mode
        expect(ecpay.service_url).to eq("https://payment-stage.ecpay.com.tw/Cashier/AioCheckOut/V5")
      end
    end

    it "raises for an invalid mode" do
      ActiveMerchant::Billing::Base.mode = :staging
      expect { ecpay.service_url }.to raise_error(StandardError, /invalid/)
    end
  end

  describe ".setup" do
    it "yields the module and stores credentials" do
      ecpay.setup do |config|
        expect(config).to equal(ecpay)
        config.merchant_id = "3000001"
        config.hash_key = "fakeHashKey12345"
        config.hash_iv = "fakeHashIV678901"
      end

      expect([ecpay.merchant_id, ecpay.hash_key, ecpay.hash_iv]).to eq(%w[3000001 fakeHashKey12345 fakeHashIV678901])
    end
  end

  describe ".notification" do
    it "builds a Notification from a raw post body" do
      notification = ecpay.notification("RtnCode=1&MerchantTradeNo=ORDER0001")

      expect(notification).to be_a(described_class::Notification)
      expect(notification.rtn_code).to eq("1")
      expect(notification.merchant_trade_no).to eq("ORDER0001")
    end
  end

  describe "constants" do
    it "defines the payment and sub payment codes" do
      expect(ecpay::PAYMENT_CREDIT_CARD).to eq("Credit")
      expect(ecpay::PAYMENT_ATM).to eq("ATM")
      expect(ecpay::PAYMENT_CVS).to eq("CVS")
      expect(ecpay::PAYMENT_ALIPAY).to eq("Alipay")
      expect(ecpay::PAYMENT_BARCODE).to eq("BARCODE")
      expect(ecpay::PAYMENT_TYPE).to eq("aio")
      expect(ecpay::SUBPAYMENT_ATM_FUBON).to eq("FUBON")
      expect(ecpay::SUBPAYMENT_CVS_FAMILY).to eq("FAMILY")
    end
  end
end
