Stripe.api_key = ENV['STRIPE_SECRET_KEY']
plans = [ { name: "Free", price_cents: 0, interval: "month" }, { name: "Pro", price_cents: 1900, interval: "month" }, { name: "Max", price_cents: 4900, interval: "month" } ]
plans.each do |plan|
  lookup_key = "plan_#{plan[:name].parameterize}_#{plan[:interval]}"
  product = Stripe::Product.list(limit: 100).data.find { |p| p.name == plan[:name] } || Stripe::Product.create(name: plan[:name])
  price = Stripe::Price.list(lookup_keys: [ lookup_key ]).data.first
  unless price
    Stripe::Price.create(currency: 'usd', recurring: { interval: plan[:interval] }, unit_amount: plan[:price_cents], product: product.id, lookup_key: lookup_key, nickname: plan[:name])
  end
end
