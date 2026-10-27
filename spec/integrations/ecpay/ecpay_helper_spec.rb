require "spec_helper"

# Helper 的欄位對應與 CheckMacValue（MD5）計算。
# 預期值皆以另一套實作（Python hashlib + urllib quote_plus，並依 ECPay 規範處理 .NET url encode）
# 獨立算出，不是用被測程式產生；金鑰皆為假資料。
RSpec.describe OffsitePayments::Integrations::Ecpay::Helper do
  let(:ecpay) { OffsitePayments::Integrations::Ecpay }
  let(:hash_key) { "fakeHashKey12345" }
  let(:hash_iv) { "fakeHashIV678901" }

  before do
    ecpay.hash_key = hash_key
    ecpay.hash_iv = hash_iv
    ecpay.merchant_id = nil
  end

  # MD5(lower(url_encode("HashKey=...&ChoosePayment=Credit&ClientBackURL=...&TradeDesc=...&HashIV=...")))
  EXPECTED_CHECK_MAC_VALUE = "5DB82E65B32420AB506A846521F26ECF".freeze

  def build_helper
    helper = described_class.new("ORDER0001", "3000001", amount: 100)
    helper.merchant_trade_date Time.new(2026, 1, 1, 10, 0, 0)
    helper.description "測試交易"
    helper.item_name "商品A 100元 x 1"
    helper.notify_url "https://example.test/ecpay/notify"
    helper.return_url "https://example.test/back?x=1&y=(2)"
    helper.choose_payment "Credit"
    helper.encrypt_type "1"
    helper
  end

  describe "#initialize" do
    it "maps order and account to MerchantTradeNo and MerchantID and fixes PaymentType to aio" do
      helper = described_class.new("ORDER0001", "3000001", amount: 100)

      expect(helper.fields).to include(
        "MerchantTradeNo" => "ORDER0001", "MerchantID" => "3000001",
        "TotalAmount" => "100", "PaymentType" => "aio"
      )
    end

    it "lets a configured global merchant_id override the account argument (current behaviour)" do
      ecpay.merchant_id = "GLOBAL1"
      helper = described_class.new("ORDER0001", "3000001")

      expect(helper.fields["MerchantID"]).to eq("GLOBAL1")
    end
  end

  describe "field mappings" do
    it "writes ECPay field names" do
      helper = described_class.new("ORDER0001", "3000001")
      helper.choose_payment "ATM"
      helper.choose_sub_payment "FUBON"
      helper.expire_date 3
      helper.payment_info_url "https://example.test/info"
      helper.client_redirect_url "https://example.test/redirect"
      helper.store_expire_date 10080
      helper.desc_1 "d1"
      helper.need_extra_paid_info "Y"
      helper.platform_id "P1"
      helper.hold_trade_amt 1
      helper.remark "備註"

      expect(helper.fields).to include(
        "ChoosePayment" => "ATM", "ChooseSubPayment" => "FUBON", "ExpireDate" => "3",
        "PaymentInfoURL" => "https://example.test/info", "ClientRedirectURL" => "https://example.test/redirect",
        "StoreExpireDate" => "10080", "Desc_1" => "d1", "NeedExtraPaidInfo" => "Y",
        "PlatformID" => "P1", "HoldTradeAMT" => "1", "Remark" => "備註"
      )
    end

    it "maps the AM common names notify_url -> ReturnURL and return_url -> ClientBackURL" do
      helper = described_class.new("ORDER0001", "3000001")
      helper.notify_url "https://example.test/notify"
      helper.return_url "https://example.test/back"

      expect(helper.fields["ReturnURL"]).to eq("https://example.test/notify")
      expect(helper.fields["ClientBackURL"]).to eq("https://example.test/back")
    end
  end

  describe "#merchant_trade_date" do
    it "formats as yyyy/MM/dd HH:mm:ss" do
      helper = described_class.new("ORDER0001", "3000001")
      helper.merchant_trade_date Time.new(2026, 3, 4, 5, 6, 7)

      expect(helper.fields["MerchantTradeDate"]).to eq("2026/03/04 05:06:07")
    end
  end

  describe "#encrypted_data" do
    it "matches the independently computed CheckMacValue" do
      helper = build_helper
      helper.encrypted_data

      expect(helper.fields["CheckMacValue"]).to eq(EXPECTED_CHECK_MAC_VALUE)
    end

    it "returns uppercase 32-hex MD5" do
      helper = build_helper
      helper.encrypted_data

      expect(helper.fields["CheckMacValue"]).to match(/\A[0-9A-F]{32}\z/)
    end

    it "changes when any field changes" do
      base = build_helper.tap(&:encrypted_data).fields["CheckMacValue"]
      changed = build_helper.tap { |h| h.amount 101 }.tap(&:encrypted_data).fields["CheckMacValue"]

      expect(changed).not_to eq(base)
    end

    it "uses per-helper hash_key / hash_iv when given" do
      helper = build_helper
      helper.hash_key "otherKey"
      helper.hash_iv "otherIV"
      helper.encrypted_data

      expect(helper.merchant_hash_key).to eq("otherKey")
      expect(helper.merchant_hash_iv).to eq("otherIV")
      expect(helper.fields["CheckMacValue"]).not_to eq(EXPECTED_CHECK_MAC_VALUE)
    end

    it "falls back to the global hash_key / hash_iv" do
      helper = build_helper

      expect(helper.merchant_hash_key).to eq(hash_key)
      expect(helper.merchant_hash_iv).to eq(hash_iv)
    end
  end

  describe ".url_encode" do
    it "encodes like .NET: space as +, keeps -_.!*() and escapes the rest in lowercase hex" do
      expect(described_class.url_encode("a b~c(d)*!_.-中&<>\n'")).to eq("a+b%7ec(d)*!_.-%e4%b8%ad%26%3c%3e%0a%27")
    end

    it "does not mutate its argument" do
      input = "a b&c".freeze

      expect { described_class.url_encode(input) }.not_to raise_error
      expect(input).to eq("a b&c")
    end

    it "returns an empty string for an empty string" do
      expect(described_class.url_encode("")).to eq("")
    end
  end

  describe "payment_service_for form" do
    def render_form(&block)
      view = ActionView::Base.empty
      view.output_buffer ||= ActionView::OutputBuffer.new # Rails 7.0 的 empty view 沒有預設 buffer
      view.payment_service_for("ORDER0001", "3000001", service: :ecpay, amount: 100, html: { id: "ecpay-form" }, &block)
      Nokogiri::HTML.fragment(view.output_buffer.to_s)
    end

    def hidden(doc, name)
      doc.at_css("input[name='#{name}']")&.[]("value")
    end

    it "posts to the stage URL with hidden fields and CheckMacValue" do
      doc = render_form do |service|
        service.merchant_trade_date Time.new(2026, 1, 1, 10, 0, 0)
        service.description "測試交易"
        service.item_name "商品A 100元 x 1"
        service.notify_url "https://example.test/ecpay/notify"
        service.return_url "https://example.test/back?x=1&y=(2)"
        service.choose_payment "Credit"
        service.encrypt_type "1"
        service.encrypted_data
      end

      form = doc.at_css("form#ecpay-form")
      expect(form["action"]).to eq("https://payment-stage.ecpay.com.tw/Cashier/AioCheckOut/V5")
      expect(form["method"]).to eq("post")
      expect(hidden(doc, "MerchantID")).to eq("3000001")
      expect(hidden(doc, "MerchantTradeNo")).to eq("ORDER0001")
      expect(hidden(doc, "TotalAmount")).to eq("100")
      expect(hidden(doc, "ItemName")).to eq("商品A 100元 x 1")
      expect(hidden(doc, "CheckMacValue")).to eq(EXPECTED_CHECK_MAC_VALUE)
    end

    it "posts to the production URL in production mode" do
      ActiveMerchant::Billing::Base.mode = :production
      doc = render_form { |service| service.choose_payment "Credit" }

      expect(doc.at_css("form")["action"]).to eq("https://payment.ecpay.com.tw/Cashier/AioCheckOut/V5")
    end

    it "raises ArgumentError without a block" do
      view = ActionView::Base.empty

      expect { view.payment_service_for("ORDER0001", "3000001", service: :ecpay) }.to raise_error(ArgumentError, /block/)
    end
  end
end
