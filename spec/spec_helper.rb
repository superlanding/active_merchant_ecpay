if ENV["COVERAGE"]
  require "simplecov"
  SimpleCov.start { add_filter "/spec/" }
end

require "bundler/setup"
require "active_merchant_ecpay"
require "net/http"
require "nokogiri"

# 測試一律不得連外部網路：任何 TCP 連線都直接 raise。
module NoNetworkInTests
  def connect
    raise "network access is disabled in tests (#{address}:#{port})"
  end
end
Net::HTTP.prepend(NoNetworkInTests)

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # 全域設定（mattr_accessor / ActiveMerchant mode）在每個 example 後還原，避免互相影響。
  config.around(:each) do |example|
    ecpay = OffsitePayments::Integrations::Ecpay
    accessors = %i[merchant_id hash_key hash_iv debug]
    saved = accessors.to_h { |a| [a, ecpay.public_send(a)] }
    saved_mode = ActiveMerchant::Billing::Base.mode
    ActiveMerchant::Billing::Base.mode = :test
    begin
      example.run
    ensure
      saved.each { |a, v| ecpay.public_send("#{a}=", v) }
      ActiveMerchant::Billing::Base.mode = saved_mode
    end
  end
end
