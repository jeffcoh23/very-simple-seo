class BillingController < ApplicationController
  allow_unauthenticated_access only: :pricing

  def pricing
    render inertia: "Marketing/Pricing", props: {
      plans: PlansService.for_frontend
    }
  end

  def subscribe
    Stripe.api_key = ENV["STRIPE_SECRET_KEY"]
    price_id = params[:price_id]

    # Verify this is a valid plan
    plan = PlansService.find_plan(price_id)
    return redirect_to pricing_path, alert: "Invalid plan selected" unless plan

    customer = current_user.payment_processor&.processor_id || current_user.set_payment_processor(:stripe).processor_id
    session = Stripe::Checkout::Session.create(
      mode: "subscription",
      line_items: [ { price: price_id, quantity: 1 } ],
      customer: customer,
      success_url: root_url,
      cancel_url: pricing_url
    )
    redirect_to session.url, allow_other_host: true
  end

  def portal
    Stripe.api_key = ENV["STRIPE_SECRET_KEY"]
    if (customer = current_user.payment_processor&.processor_id)
      session = Stripe::BillingPortal::Session.create(customer: customer, return_url: settings_url)
      redirect_to session.url, allow_other_host: true
    else
      redirect_to pricing_url, alert: "No payment method on file"
    end
  end
end
