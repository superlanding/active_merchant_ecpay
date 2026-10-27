require "spec_helper"
require "uri"

# Notification 的 CheckMacValue 驗證、RtnCode 判斷與欄位 accessor。
# 預期的 CheckMacValue 皆以 Python 獨立計算；金鑰皆為假資料。
RSpec.describe OffsitePayments::Integrations::Ecpay::Notification do
  let(:ecpay) { OffsitePayments::Integrations::Ecpay }
  let(:hash_key) { "fakeHashKey12345" }
  let(:hash_iv) { "fakeHashIV678901" }

  # 信用卡付款成功通知（不含 CheckMacValue 的欄位）
  let(:base_params) do
    {
      "MerchantID" => "3000001", "MerchantTradeNo" => "ORDER0001", "RtnCode" => "1",
      "RtnMsg" => "交易成功", "TradeNo" => "2601011000000001", "TradeAmt" => "100",
      "PaymentDate" => "2026/01/01 10:05:00", "PaymentType" => "Credit_CreditCard",
      "PaymentTypeChargeFee" => "2", "TradeDate" => "2026/01/01 10:00:00",
      "SimulatePaid" => "0", "card4no" => "2222"
    }
  end
  let(:valid_mac) { "06C42CC2825054A629C1D398D73A7B99" }

  before do
    ecpay.hash_key = hash_key
    ecpay.hash_iv = hash_iv
  end

  def build(overrides = {}, options = {})
    mac = options.fetch(:mac, valid_mac)
    params = base_params.merge(overrides)
    params = params.merge("CheckMacValue" => mac) if mac
    params.delete_if { |_, v| v.nil? }
    described_class.new(URI.encode_www_form(params))
  end

  describe "#checksum_ok?" do
    it "accepts an independently computed CheckMacValue" do
      expect(build).to be_checksum_ok
    end

    it "accepts a lowercase CheckMacValue" do
      expect(build({}, mac: valid_mac.downcase)).to be_checksum_ok
    end

    it "sorts keys case-insensitively (mixed case keys such as vAccount / card4no)" do
      mixed = base_params.merge("vAccount" => "9999912345678", "BankCode" => "812", "ExpireDate" => "2026/01/10")

      expect(build(mixed.slice("vAccount", "BankCode", "ExpireDate"), mac: "18301FC4582AB1CFD30C004DE49A0634")).to be_checksum_ok
    end

    it "rejects a tampered amount, order number or return code" do
      expect(build("TradeAmt" => "1")).not_to be_checksum_ok
      expect(build("MerchantTradeNo" => "ORDER0002")).not_to be_checksum_ok
      expect(build("RtnCode" => "0")).not_to be_checksum_ok
    end

    it "rejects an extra injected parameter" do
      expect(build("Injected" => "1")).not_to be_checksum_ok
    end

    it "rejects wrong hash key or iv" do
      wrong_key = build.tap { |n| n.hash_key = "wrongKey" }
      wrong_iv = build.tap { |n| n.hash_iv = "wrongIV" }

      expect(wrong_key).not_to be_checksum_ok
      expect(wrong_iv).not_to be_checksum_ok
    end

    it "uses the instance hash_key / hash_iv over the global config" do
      ecpay.hash_key = "wrong"
      ecpay.hash_iv = "wrong"
      notification = build
      notification.hash_key = hash_key
      notification.hash_iv = hash_iv

      expect(notification).to be_checksum_ok
    end

    it "returns false instead of raising when CheckMacValue is missing" do
      expect(build({}, mac: nil)).not_to be_checksum_ok
    end

    it "does not mutate the parsed params" do
      notification = build
      notification.checksum_ok?

      expect(notification.params["CheckMacValue"]).to eq(valid_mac)
    end

    it "is aliased by #acknowledge" do
      expect(build.acknowledge).to eq(true)
      expect(build("TradeAmt" => "1").acknowledge).to eq(false)
    end
  end

  describe "status and #complete?" do
    {
      "1" => true,
      "2" => true,
      "10100073" => true,
      "800" => true,
      "0" => false,
      "10100058" => false,
      "" => false
    }.each do |code, expected|
      it "RtnCode #{code.inspect} complete? == #{expected}" do
        expect(build("RtnCode" => code).complete?).to eq(expected)
      end
    end

    it "#status is true only for RtnCode 1" do
      expect(build("RtnCode" => "1").status).to eq(true)
      expect(build("RtnCode" => "2").status).to eq(false)
      expect(build("RtnCode" => nil).status).to eq(false)
    end
  end

  describe "accessors" do
    subject(:notification) { build }

    it "returns decoded params" do
      expect(notification.rtn_code).to eq("1")
      expect(notification.rtn_msg).to eq("交易成功")
      expect(notification.merchant_id).to eq("3000001")
      expect(notification.merchant_trade_no).to eq("ORDER0001")
      expect(notification.item_id).to eq("ORDER0001")
      expect(notification.trade_no).to eq("2601011000000001")
      expect(notification.transaction_id).to eq("2601011000000001")
      expect(notification.trade_amt).to eq("100")
      expect(notification.payment_date).to eq("2026/01/01 10:05:00")
      expect(notification.payment_type).to eq("Credit_CreditCard")
      expect(notification.payment_type_charge_fee).to eq("2")
      expect(notification.trade_date).to eq("2026/01/01 10:00:00")
      expect(notification.simulate_paid).to eq("0")
      expect(notification.check_mac_value).to eq(valid_mac)
      expect(notification.card4no).to eq("2222")
    end

    it "returns the amount as TWD Money" do
      expect(notification.currency).to eq("TWD")
      expect(notification.gross).to eq(Money.new(10_000, "TWD"))
    end

    it "returns ATM, CVS and BARCODE fields" do
      atm = build("BankCode" => "812", "vAccount" => "9999912345678", "ExpireDate" => "2026/01/10",
                  "PaymentNo" => "LLL26010100001", "Barcode1" => "b1", "Barcode2" => "b2", "Barcode3" => "b3")

      expect(atm.bank_code).to eq("812")
      expect(atm.v_account).to eq("9999912345678")
      expect(atm.expire_date).to eq("2026/01/10")
      expect(atm.payment_no).to eq("LLL26010100001")
      expect([atm.barcode1, atm.barcode2, atm.barcode3]).to eq(%w[b1 b2 b3])
    end

    it "returns nil for params that were not posted" do
      expect(notification.bank_code).to be_nil
      expect(notification.payment_no).to be_nil
    end
  end
end
