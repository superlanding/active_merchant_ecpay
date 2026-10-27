# ActiveMerchantEcpay

為 Rails 提供台灣 **ECPay（綠界科技 / 歐付寶）** AIO 全方位金流結帳的 [ActiveMerchant](https://github.com/activemerchant/active_merchant) / [OffsitePayments](https://github.com/activemerchant/offsite_payments) 整合。有了它，Rails 應用程式可以：

- 產生含 hidden 欄位的表單，把消費者導向 ECPay 的付款頁（包含 `CheckMacValue` 簽章），以及
- 解析並驗證 ECPay 回傳到伺服器的通知（`ReturnURL`）。

helper 常數支援的付款方式：信用卡（`Credit`）、虛擬帳號 ATM（`ATM`）、超商代碼（`CVS`）、超商條碼（`BARCODE`）與 `Alipay`（支付寶）。

這個 gem 發佈在 [RubyGems](https://rubygems.org/gems/active_merchant_ecpay)。各版本的變更請見 [CHANGELOG.md](CHANGELOG.md)。

## 環境需求

| | 支援版本 |
| --- | --- |
| Ruby | 3.0、3.1、3.2、3.3、3.4 |
| Rails（`actionview` / `activesupport`） | 7.0、7.1、7.2、8.0、8.1 |

Rails 7.2 需要 Ruby >= 3.1，Rails 8.0 / 8.1 需要 Ruby >= 3.2。以上正是 CI 矩陣（`.github/workflows/test.yml`）所跑的組合。其他 runtime 相依套件：`activemerchant ~> 1.50`、`offsite_payments ~> 2`、`money`。

## 安裝

在應用程式的 `Gemfile` 加入這一行：

```ruby
gem 'active_merchant_ecpay', '>= 0.2.0'
```

然後執行：

```sh
bundle install
```

> 支援 Rails 7+ / Ruby 3+ 的版本是 **0.2.0**。如果 RubyGems 上還看不到 0.2.0（請查看 [CHANGELOG](CHANGELOG.md)；0.1.2 是支援舊版 Rails 的最後一個版本），請改用 Git 來源：
> `gem 'active_merchant_ecpay', github: 'superlanding/active_merchant_ecpay'`。

## 設定

從 ECPay 取得你的商店憑證（[API 規格](https://developers.ecpay.com.tw/)有說明每個參數）。接著建立 initializer，例如 `config/initializers/ecpay.rb`：

```ruby
OffsitePayments::Integrations::Ecpay.setup do |ecpay|
  if Rails.env.production?
    ecpay.merchant_id = Rails.application.credentials.dig(:ecpay, :merchant_id)
    ecpay.hash_key    = Rails.application.credentials.dig(:ecpay, :hash_key)
    ecpay.hash_iv     = Rails.application.credentials.dig(:ecpay, :hash_iv)
  else
    # ECPay 公開的 stage（測試）帳號
    ecpay.merchant_id = '2000132'
    ecpay.hash_key    = '5294y06JbISpM5x9'
    ecpay.hash_iv     = 'v77hoKGq4kWxNNIS'
  end
end
```

選擇環境。付款閘道的 URL 取決於 `ActiveMerchant::Billing::Base.mode`：

| mode | URL |
| --- | --- |
| `:production` | `https://payment.ecpay.com.tw/Cashier/AioCheckOut/V5` |
| `:development` / `:test` | `https://payment-stage.ecpay.com.tw/Cashier/AioCheckOut/V5`（stage 測試環境） |

```ruby
# config/environments/development.rb
config.after_initialize do
  ActiveMerchant::Billing::Base.mode = :development
end

# config/environments/production.rb
config.after_initialize do
  ActiveMerchant::Billing::Base.mode = :production
end
```

## 使用方式

### 1. 把消費者導向付款頁

`payment_service_for` 可以在 view 裡使用。請一律最後才呼叫 `service.encrypted_data`；它會用目前已設定的所有欄位計算 `CheckMacValue`（MD5，採用 ECPay 的 .NET 風格 URL encode）。

```erb
<% payment_service_for @order.id,
                       @order.user.email,
                       service: :ecpay,
                       html: { method: :post } do |service| %>
  <% service.merchant_trade_no "#{@order.id}T#{Time.current.to_i}" %>   <%# 不可重複，僅限英數字，最多 20 個字元 %>
  <% service.merchant_trade_date @order.created_at %>                   <%# 格式為 yyyy/MM/dd HH:mm:ss %>
  <% service.total_amount @order.total.to_i %>
  <% service.description 'Order description' %>
  <% service.item_name 'Item name' %>
  <% service.choose_payment OffsitePayments::Integrations::Ecpay::PAYMENT_ATM %>
  <% service.return_url root_url %>                                     <%# ClientBackURL：ECPay 頁面上導回你網站的按鈕 %>
  <% service.notify_url ecpay_notify_url %>                             <%# ReturnURL：伺服器對伺服器的付款結果通知 %>
  <% service.encrypted_data %>
  <%= submit_tag 'Buy!' %>
<% end %>
```

輸出的 `<form method="post">` 會指向上述閘道 URL，內含 hidden 欄位 `MerchantID`、`PaymentType`（`aio`）、`MerchantTradeNo`、`MerchantTradeDate`、`TotalAmount`、`TradeDesc`、`ItemName`、`ChoosePayment`、`ClientBackURL`、`ReturnURL`、`CheckMacValue`。

付款方式常數：`PAYMENT_CREDIT_CARD`、`PAYMENT_ATM`、`PAYMENT_CVS`、`PAYMENT_ALIPAY`、`PAYMENT_BARCODE`；子付款方式常數 `SUBPAYMENT_ATM_*`（`TAISHIN`、`ESUN`、`HUANAN`、`BOT`、`FUBON`、`CHINATRUST`、`FIRST`）與 `SUBPAYMENT_CVS_*`（`CVS`、`OK`、`FAMILY`、`HILIFE`、`IBON`），搭配 `service.choose_sub_payment` 使用。

其他欄位 setter（snake_case → ECPay 參數）：`merchant_id` / `account` → `MerchantID`、`merchant_trade_no` / `order` → `MerchantTradeNo`、`total_amount` / `amount` → `TotalAmount`、`notify_url` → `ReturnURL`、`client_back_url` / `return_url` → `ClientBackURL`、`redirect_url` → `OrderResultURL`、`payment_info_url` → `PaymentInfoURL`、`client_redirect_url` / `payment_redirect_url` → `ClientRedirectURL`、`item_url`、`remark`、`need_extra_paid_info`、`devise_source`、`ignore_payment`、`platform_id`、`invoice_mark`、`hold_trade_amt`、`encrypt_type`、`expire_date`（ATM）、`store_expire_date`、`desc_1` … `desc_4`（CVS / BARCODE），以及 Alipay 欄位 `alipay_item_name`、`alipay_item_counts`、`alipay_item_price`、`email`、`phone_no`、`uder_name`（原文如此，是拼錯的名稱）、`expire_time`。

如果某張表單要用不同的 HashKey / HashIV（例如有多個商店），請在 `service.encrypted_data` 之前呼叫 `service.hash_key '...'` 與 `service.hash_iv '...'`。

### 2. 處理通知

把 `notify_url` 指向某個 controller action，該 action 要略過 CSRF 驗證，並且在信任資料之前先驗證簽章：

```ruby
class EcpayController < ApplicationController
  skip_before_action :verify_authenticity_token, only: :notify

  def notify
    notification = OffsitePayments::Integrations::Ecpay.notification(request.raw_post)

    if notification.checksum_ok? && notification.complete?
      order = Order.find_by!(id: notification.merchant_trade_no.split('T').first)
      # notification.trade_no, notification.trade_amt, notification.payment_type, notification.payment_date ...
      order.mark_as_paid!(trade_no: notification.trade_no) if notification.status
    end

    render plain: '1|OK'   # ECPay 要求回應的 body 必須是 "1|OK"
  end
end
```

notification 上可用的輔助方法：

- `checksum_ok?` / `acknowledge`：以你的 `HashKey` / `HashIV` 驗證 `CheckMacValue`。ECPay 沒有遠端驗證機制，所以這是唯一的真偽檢查，**請務必呼叫**。
- `status`：`RtnCode == '1'`（已付款）時為 `true`。`complete?`：除了已付款，遇到「已取號」的代碼時也會是 `true`：`2`（ATM 虛擬帳號已產生）、`10100073`（CVS / BARCODE 代碼已產生）與 `800`（貨到付款訂單已建立）。要判斷是否真的收到款項，請用 `status`。
- reader：`rtn_code`、`rtn_msg`、`merchant_id`、`merchant_trade_no`（別名 `item_id`）、`trade_no`（別名 `transaction_id`）、`trade_amt`、`gross`（以 TWD 計價的 `Money`）、`payment_date`、`payment_type`、`payment_type_charge_fee`、`trade_date`、`simulate_paid`、`check_mac_value`；ATM：`bank_code`、`v_account`、`expire_date`；信用卡：`card4no`；CVS：`payment_no`；BARCODE：`barcode1`、`barcode2`、`barcode3`。
- 若要用各商店自己的金鑰驗證，請在 `checksum_ok?` 之前設定 `notification.hash_key = '...'` 與 `notification.hash_iv = '...'`。

### 已知限制

- `Helper.url_encode` 對欄位值裡的 `<`、換行、carriage return 與 `&`，目前的編碼方式還不符合 ECPay 的規定（見 `helper.rb` 裡的 TODO）；請避免在 `description` / `item_name` 使用這些字元。
- 設定 `OffsitePayments::Integrations::Ecpay.debug = true` 會在 `encrypted_data` 裡呼叫 `binding.pry`（需要 `pry` gem）；請絕對不要在正式環境開啟。

## 開發

```sh
git clone https://github.com/superlanding/active_merchant_ecpay.git
cd active_merchant_ecpay
BUNDLE_GEMFILE=gemfiles/rails_8.1.gemfile bundle install
BUNDLE_GEMFILE=gemfiles/rails_8.1.gemfile bundle exec rake t   # `rake spec` 的別名
```

請在 `gemfiles/` 裡挑一個符合你 Ruby 版本的 gemfile（`rails_7.0` … `rails_8.1`）。測試使用 RSpec，放在 `spec/`，並且會封鎖所有網路存取（任何 `Net::HTTP` 連線都會 raise）。設定 `COVERAGE=1` 可執行 SimpleCov。

CI（`.github/workflows/test.yml`）會在每個 PR 以及 push 到 `master` 時跑完整的 Ruby × Rails 矩陣。

## 發版

發版是自動的（RubyGems [Trusted Publishing](https://guides.rubygems.org/trusted-publishing/)，不存放 API key）：

1. 在你的 PR 裡修改 `lib/active_merchant_ecpay/version.rb` 的 `ActiveMerchantEcpay::VERSION`（SemVer），並把 `CHANGELOG.md` 裡 `## [Unreleased]` 底下的條目移到新的 `## [x.y.z] - YYYY-MM-DD` 區塊。
2. 把 PR 合併進 `master`。
3. `.github/workflows/publish.yml` 發現這個版本還不在 rubygems.org 上，就會打包 gem 並執行 `rake release`，發佈 gem 並建立 `vx.y.z` git tag。如果該版本已經存在，workflow 什麼都不會做。

沒有跳版號的 PR（文件、CI、重構）永遠不會被發佈。

## 貢獻

歡迎到 GitHub 回報問題與提交 pull request：https://github.com/superlanding/active_merchant_ecpay。每個 pull request 也都必須同步更新這份 README（當行為、用法或環境需求有變時），並在 `CHANGELOG.md` 新增一筆條目；請見 `CLAUDE.md`。

## 授權

本 gem 以 [MIT License](LICENSE.txt) 條款開源。
