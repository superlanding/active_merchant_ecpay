# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'active_merchant_ecpay/version'

Gem::Specification.new do |spec|
  spec.name          = "active_merchant_ecpay"
  spec.version       = ActiveMerchantEcpay::VERSION
  spec.authors       = ["Eddie Li"]
  spec.email         = ["eddie@super-landing.com"]

  spec.summary       = %q{ActiveMerchant x Ecpay (綠界科技)}
  spec.description   = %q{This gem integrate Rails with ecpay (綠界科技).}
  spec.homepage      = "https://github.com/superlanding/active_merchant_ecpay"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency 'activemerchant', '~> 1.50'
  spec.add_dependency 'money'
  spec.add_dependency 'offsite_payments', '~> 2'

  spec.add_development_dependency "bundler", "~> 1.14"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency('mocha', '~> 0.13.0')
  spec.add_development_dependency('rails', '>= 2.3.14')
  spec.add_development_dependency('pry')
  spec.add_development_dependency('thor')
end
