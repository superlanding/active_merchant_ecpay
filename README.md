# ActiveMerchantEcpay

[ActiveMerchant](https://github.com/activemerchant/active_merchant) / [OffsitePayments](https://github.com/activemerchant/offsite_payments) integration for **ECPay (綠界科技 / 歐付寶)** AIO checkout in Taiwan, for Rails. It lets a Rails app:

- render the hidden-field form that sends a customer to the ECPay payment page (including the `CheckMacValue` signature), and
- parse and verify the server notification (`ReturnURL`) ECPay posts back.

Payment methods supported by the helper constants: credit card (`Credit`), virtual ATM (`ATM`), convenience store code (`CVS`), barcode (`BARCODE`) and `Alipay`.

The gem is published on [RubyGems](https://rubygems.org/gems/active_merchant_ecpay). See [CHANGELOG.md](CHANGELOG.md) for what changed in each version.

## Requirements

| | Supported |
| --- | --- |
| Ruby | 3.0, 3.1, 3.2, 3.3, 3.4 |
| Rails (`actionview` / `activesupport`) | 7.0, 7.1, 7.2, 8.0, 8.1 |

Rails 7.2 needs Ruby >= 3.1, and Rails 8.0 / 8.1 need Ruby >= 3.2. These are exactly the combinations the CI matrix (`.github/workflows/test.yml`) runs. Other runtime dependencies: `activemerchant ~> 1.50`, `offsite_payments ~> 2`, `money`.

## Installation

Add this line to your application's `Gemfile`:

```ruby
gem 'active_merchant_ecpay', '>= 0.2.0'
```

Then run:

```sh
bundle install
```

> Support for Rails 7+ / Ruby 3+ is released as **0.2.0**. If 0.2.0 is not yet visible on RubyGems (check the [CHANGELOG](CHANGELOG.md); 0.1.2 is the last release for older Rails), use the Git source instead:
> `gem 'active_merchant_ecpay', github: 'superlanding/active_merchant_ecpay'`.

## Configuration

Get your merchant credentials from ECPay (the [API spec](https://developers.ecpay.com.tw/) describes every parameter). Then create an initializer, e.g. `config/initializers/ecpay.rb`:

```ruby
OffsitePayments::Integrations::Ecpay.setup do |ecpay|
  if Rails.env.production?
    ecpay.merchant_id = Rails.application.credentials.dig(:ecpay, :merchant_id)
    ecpay.hash_key    = Rails.application.credentials.dig(:ecpay, :hash_key)
    ecpay.hash_iv     = Rails.application.credentials.dig(:ecpay, :hash_iv)
  else
    # ECPay's public stage (test) account
    ecpay.merchant_id = '2000132'
    ecpay.hash_key    = '5294y06JbISpM5x9'
    ecpay.hash_iv     = 'v77hoKGq4kWxNNIS'
  end
end
```

Choose the environment. The gateway URL depends on `ActiveMerchant::Billing::Base.mode`:

| mode | URL |
| --- | --- |
| `:production` | `https://payment.ecpay.com.tw/Cashier/AioCheckOut/V5` |
| `:development` / `:test` | `https://payment-stage.ecpay.com.tw/Cashier/AioCheckOut/V5` (stage) |

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

## Usage

### 1. Send the customer to the payment page

`payment_service_for` is available in views. Always call `service.encrypted_data` last; it computes `CheckMacValue` from every field set so far (MD5, ECPay's .NET-style URL encoding).

```erb
<% payment_service_for @order.id,
                       @order.user.email,
                       service: :ecpay,
                       html: { method: :post } do |service| %>
  <% service.merchant_trade_no "#{@order.id}T#{Time.current.to_i}" %>   <%# unique, alphanumeric, max 20 chars %>
  <% service.merchant_trade_date @order.created_at %>                   <%# formatted as yyyy/MM/dd HH:mm:ss %>
  <% service.total_amount @order.total.to_i %>
  <% service.description 'Order description' %>
  <% service.item_name 'Item name' %>
  <% service.choose_payment OffsitePayments::Integrations::Ecpay::PAYMENT_ATM %>
  <% service.return_url root_url %>                                     <%# ClientBackURL: button on the ECPay page back to your site %>
  <% service.notify_url ecpay_notify_url %>                             <%# ReturnURL: server-to-server payment result %>
  <% service.encrypted_data %>
  <%= submit_tag 'Buy!' %>
<% end %>
```

The rendered `<form method="post">` points at the gateway URL above, with hidden inputs `MerchantID`, `PaymentType` (`aio`), `MerchantTradeNo`, `MerchantTradeDate`, `TotalAmount`, `TradeDesc`, `ItemName`, `ChoosePayment`, `ClientBackURL`, `ReturnURL`, `CheckMacValue`.

Payment method constants: `PAYMENT_CREDIT_CARD`, `PAYMENT_ATM`, `PAYMENT_CVS`, `PAYMENT_ALIPAY`, `PAYMENT_BARCODE`; sub-payment constants `SUBPAYMENT_ATM_*` (`TAISHIN`, `ESUN`, `HUANAN`, `BOT`, `FUBON`, `CHINATRUST`, `FIRST`) and `SUBPAYMENT_CVS_*` (`CVS`, `OK`, `FAMILY`, `HILIFE`, `IBON`), used with `service.choose_sub_payment`.

Other field setters (snake_case → ECPay parameter): `merchant_id` / `account` → `MerchantID`, `merchant_trade_no` / `order` → `MerchantTradeNo`, `total_amount` / `amount` → `TotalAmount`, `notify_url` → `ReturnURL`, `client_back_url` / `return_url` → `ClientBackURL`, `redirect_url` → `OrderResultURL`, `payment_info_url` → `PaymentInfoURL`, `client_redirect_url` / `payment_redirect_url` → `ClientRedirectURL`, `item_url`, `remark`, `need_extra_paid_info`, `devise_source`, `ignore_payment`, `platform_id`, `invoice_mark`, `hold_trade_amt`, `encrypt_type`, `expire_date` (ATM), `store_expire_date`, `desc_1` … `desc_4` (CVS / BARCODE), and the Alipay fields `alipay_item_name`, `alipay_item_counts`, `alipay_item_price`, `email`, `phone_no`, `uder_name` (sic), `expire_time`.

To use a different HashKey / HashIV for one form (for example for multiple merchants), call `service.hash_key '...'` and `service.hash_iv '...'` before `service.encrypted_data`.

### 2. Handle the notification

Point `notify_url` at a controller action, skip CSRF verification for it, and verify the signature before trusting the data:

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

    render plain: '1|OK'   # ECPay expects "1|OK" as the response body
  end
end
```

Available helpers on the notification:

- `checksum_ok?` / `acknowledge` — verifies `CheckMacValue` with your `HashKey` / `HashIV`. ECPay has no remote verification, so this is the only authenticity check; **always call it**.
- `status` — `true` when `RtnCode == '1'` (paid). `complete?` — also `true` for the "number issued" codes: `2` (ATM virtual account issued), `10100073` (CVS / BARCODE code issued) and `800` (cash-on-delivery order created). Use `status` to know whether money was actually received.
- Readers: `rtn_code`, `rtn_msg`, `merchant_id`, `merchant_trade_no` (alias `item_id`), `trade_no` (alias `transaction_id`), `trade_amt`, `gross` (`Money` in TWD), `payment_date`, `payment_type`, `payment_type_charge_fee`, `trade_date`, `simulate_paid`, `check_mac_value`; ATM: `bank_code`, `v_account`, `expire_date`; credit card: `card4no`; CVS: `payment_no`; BARCODE: `barcode1`, `barcode2`, `barcode3`.
- To verify with a per-merchant key, set `notification.hash_key = '...'` and `notification.hash_iv = '...'` before `checksum_ok?`.

### Known limitations

- `Helper.url_encode` does not yet match ECPay's encoding for `<`, newline, carriage return and `&` inside field values (see the TODO in `helper.rb`); avoid them in `description` / `item_name`.
- Setting `OffsitePayments::Integrations::Ecpay.debug = true` calls `binding.pry` inside `encrypted_data` (needs the `pry` gem); never enable it in production.

## Development

```sh
git clone https://github.com/superlanding/active_merchant_ecpay.git
cd active_merchant_ecpay
BUNDLE_GEMFILE=gemfiles/rails_8.1.gemfile bundle install
BUNDLE_GEMFILE=gemfiles/rails_8.1.gemfile bundle exec rake t   # alias of `rake spec`
```

Pick any gemfile in `gemfiles/` (`rails_7.0` … `rails_8.1`) that matches your Ruby version. The specs are RSpec, live in `spec/`, and block all network access (any `Net::HTTP` connection raises). Set `COVERAGE=1` to run SimpleCov.

CI (`.github/workflows/test.yml`) runs the whole Ruby × Rails matrix for every PR and push to `master`.

## Releasing

Releases are automatic (RubyGems [Trusted Publishing](https://guides.rubygems.org/trusted-publishing/), no API key stored):

1. In your PR, bump `ActiveMerchantEcpay::VERSION` in `lib/active_merchant_ecpay/version.rb` (SemVer) and move the `## [Unreleased]` entries in `CHANGELOG.md` under a new `## [x.y.z] - YYYY-MM-DD` section.
2. Merge the PR into `master`.
3. `.github/workflows/publish.yml` sees that the version is not on rubygems.org yet, builds the gem and runs `rake release`, which publishes it and creates the `vx.y.z` git tag. If the version already exists, the workflow does nothing.

PRs that do not bump the version (docs, CI, refactors) are never published.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/superlanding/active_merchant_ecpay. Every pull request must also update this README (when behaviour, usage or requirements change) and add an entry to `CHANGELOG.md`; see `CLAUDE.md`.

## License

The gem is available as open source under the terms of the [MIT License](LICENSE.txt).
