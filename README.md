# ActiveMerchantEcpay

This plugin is an active_merchant patch for ecpay(歐付寶) online payment in Taiwan.
Now it supports:
 - Credit card(信用卡)
 - ATM(虛擬ATM)
 - BARCODE(超商條碼).

It has been tested on Rails 4.2 successfully.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'active_merchant_ecpay'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install active_merchant_ecpay

## Usage

You can get Payment API and SPEC in [Ecpay API](https://www.ecpay.com.tw/Content/files/ecpay_011.pdf).
Then create an initializer, like initializers/ecpay.rb. Add the following configurations depends on your settings.

``` ruby
# config/environments/development.rb
config.after_initialize do
  ActiveMerchant::Billing::Base.mode = :development
end

# config/environments/production.rb
config.after_initialize do
  ActiveMerchant::Billing::Base.mode = :production
end
```

``` ruby
# initializers/ecpay.rb
OffsitePayments::Integrations::Ecpay.setup do |ecpay|
  if Rails.env.development?
    # default setting for stage test
    ecpay.merchant_id = '2000132'
    ecpay.hash_key    = '5294y06JbISpM5x9'
    ecpay.hash_iv     = 'v77hoKGq4kWxNNIS'
  else
    # change to yours
    ecpay.merchant_id = '23466XX'
    ecpay.hash_key    = 'adfasdsfgseweqwg'
    ecpay.hash_iv     = '15y3ersee34yasdf'
  end
end
```

Once you’ve configured ActiveMerchantEcpay, you need a checkout form; it looks like:

``` erb
<% payment_service_for  @order.id,
                        @order.user.email,
                        service: :ecpay,
                        html:    { method: :post } do |service| %>
  <% service.merchant_trade_no "#{@order.id}T#{Time.zone.now}" %>
  <% service.merchant_trade_date @order.created_at %>
  <% service.total_amount @order.total.to_i %>
  <% service.description @order.id %>
  <% service.item_name @order.id %>
  <% service.choose_payment OffsitePayments::Integrations::Ecpay::PAYMENT_ATM %>
  <% service.return_url root_path %>
  <% service.notify_url ecpay_atm_return_url %>
  <% service.encrypted_data %>
  <%= submit_tag 'Buy!' %>
<% end %>
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/superlanding/active_merchant_ecpay.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

