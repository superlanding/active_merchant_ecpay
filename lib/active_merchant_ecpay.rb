require 'action_view'
require "active_merchant_ecpay/version"
require 'active_merchant'
require 'offsite_payments'

module OffsitePayments
  module Integrations
    autoload :Ecpay, 'offsite_payments/integrations/ecpay'
  end
end

ActionView::Base.send(:include, OffsitePayments::ActionViewHelper)
