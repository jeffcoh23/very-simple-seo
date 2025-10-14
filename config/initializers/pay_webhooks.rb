# config/initializers/pay_webhooks.rb

# Pay gem configuration
Pay.setup do |config|
  # Email configuration
  config.emails.receipt = true
  config.emails.payment_failed = true
end

# Helper methods for webhooks
module PayWebhookHelpers
  def self.find_customer_and_user(customer_id)
    customer = Pay::Customer.find_by(processor_id: customer_id)
    return [ nil, nil ] if customer.nil? || customer.owner.nil?
    [ customer, customer.owner ]
  end

  def self.extract_subscription_info(event)
    subscription_data = event.data.object
    customer_id = subscription_data.customer
    price_id = subscription_data.items&.data&.first&.price&.id
    [ subscription_data, customer_id, price_id ]
  end
end

# Custom webhook handlers for Pay gem
ActiveSupport.on_load(:pay) do
  # SUBSCRIPTION LIFECYCLE WEBHOOKS - These actually update credits

  # Subscription created - user gets credits for their plan
  [ "stripe.customer.subscription.created", "customer.subscription.created" ].each do |event_type|
    Pay::Webhooks.delegator.subscribe event_type do |event|
      Rails.logger.info "Processing #{event_type} webhook"

      _, customer_id, price_id = PayWebhookHelpers.extract_subscription_info(event)
      _, user = PayWebhookHelpers.find_customer_and_user(customer_id)

      unless user
        Rails.logger.error "Customer #{customer_id} not found or has no owner"
        next
      end

      credits = PlansService.credits_for_plan(price_id)
      Rails.logger.info "Granting #{credits} credits to user #{user.id} (#{user.email_address}) for subscription creation"

      user.update!(credits: credits)
      Rails.logger.info "Successfully granted #{credits} credits to user #{user.id}"
    end
  end

  # Subscription updated - user gets credits for new plan (only if plan actually changed)
  [ "stripe.customer.subscription.updated", "customer.subscription.updated" ].each do |event_type|
    Pay::Webhooks.delegator.subscribe event_type do |event|
      Rails.logger.info "Processing #{event_type} webhook"

      subscription_data, customer_id, price_id = PayWebhookHelpers.extract_subscription_info(event)
      _, user = PayWebhookHelpers.find_customer_and_user(customer_id)

      unless user
        Rails.logger.error "Customer #{customer_id} not found or has no owner"
        next
      end

      # Only update credits if the plan actually changed
      old_price = subscription_data.previous_attributes&.dig("items", "data", 0, "price", "id")
      if old_price && old_price != price_id
        credits = PlansService.credits_for_plan(price_id)
        Rails.logger.info "Plan changed for user #{user.id}: #{old_price} -> #{price_id}, updating to #{credits} credits"
        user.update!(credits: credits)
        Rails.logger.info "Successfully updated user #{user.id} to #{credits} credits"
      else
        Rails.logger.info "No plan change detected for user #{user.id}, skipping credit update"
      end
    end
  end

  # Subscription deleted - user goes back to free tier
  [ "stripe.customer.subscription.deleted", "customer.subscription.deleted" ].each do |event_type|
    Pay::Webhooks.delegator.subscribe event_type do |event|
      Rails.logger.info "Processing #{event_type} webhook"

      customer_id = event.data.object.customer
      _, user = PayWebhookHelpers.find_customer_and_user(customer_id)

      unless user
        Rails.logger.error "Customer #{customer_id} not found or has no owner"
        next
      end

      free_credits = PlansService.free_tier_credits
      Rails.logger.info "Subscription deleted for user #{user.id}, reverting to free plan (#{free_credits} credits)"
      user.update!(credits: free_credits)
      Rails.logger.info "Successfully reverted user #{user.id} to free tier (#{free_credits} credits)"
    end
  end

  # Customer deleted - customer was deleted from Stripe, revert to free tier
  [ "stripe.customer.deleted", "customer.deleted" ].each do |event_type|
    Pay::Webhooks.delegator.subscribe event_type do |event|
      Rails.logger.info "Processing #{event_type} webhook"

      customer_id = event.data.object.id
      _, user = PayWebhookHelpers.find_customer_and_user(customer_id)

      unless user
        Rails.logger.error "Customer #{customer_id} not found or has no owner"
        next
      end

      Rails.logger.warn "Customer deleted for user #{user.id} - reverting to free tier"
      user.update!(credits: PlansService.free_tier_credits)
      Rails.logger.info "Successfully reverted user #{user.id} to free tier"
    end
  end

  # Charge refunded - for full refunds, optionally revert to free tier
  [ "stripe.charge.refunded", "charge.refunded" ].each do |event_type|
    Pay::Webhooks.delegator.subscribe event_type do |event|
      Rails.logger.info "Processing #{event_type} webhook"

      charge_data = event.data.object
      customer_id = charge_data.customer
      _, user = PayWebhookHelpers.find_customer_and_user(customer_id)

      next unless user

      Rails.logger.info "Charge refunded for user #{user.id}: #{charge_data.amount_refunded / 100.0} #{charge_data.currency.upcase}"

      # For full refunds, optionally revert to free tier
      if charge_data.amount_refunded == charge_data.amount
        Rails.logger.info "Full refund detected for user #{user.id} - consider reverting to free tier"
        # Uncomment if you want to automatically revert on full refund:
        # user.update!(credits: PlansService.free_tier_credits)
      end
    end
  end

  # Invoice payment failed - log for monitoring, don't revoke credits immediately
  [ "stripe.invoice.payment_failed", "invoice.payment_failed" ].each do |event_type|
    Pay::Webhooks.delegator.subscribe event_type do |event|
      Rails.logger.info "Processing #{event_type} webhook"

      customer_id = event.data.object.customer
      _, user = PayWebhookHelpers.find_customer_and_user(customer_id)

      next unless user

      Rails.logger.warn "Invoice payment failed for user #{user.id} - Stripe will retry"
      # Don't immediately revoke credits - let Stripe handle retries
      # TODO: Send payment failed notification email
    end
  end
end
