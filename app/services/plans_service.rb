class PlansService
  # Environment-specific price IDs
  PRICE_IDS = {
    test: {
      pro: "price_test_pro",
      max: "price_test_max"
    },
    development: {
      pro: "price_dev_pro",
      max: "price_dev_max"
    },
    production: {
      pro: "price_prod_pro",  # Replace with actual Stripe price ID
      max: "price_prod_max"   # Replace with actual Stripe price ID
    }
  }.freeze

  # Get current environment price IDs
  def self.current_price_ids
    env = Rails.env.to_sym
    PRICE_IDS[env] || PRICE_IDS[:development]
  end

  # Centralized plan configuration - single source of truth
  def self.plan_config
    price_ids = current_price_ids

    {
      "free" => {
        name: "Free",
        price: 0,
        stripe_price_id: nil,
        popular: false,
        features: [
          "Basic features",
          "Email support",
          "Cancel anytime"
        ]
      },
      price_ids[:pro] => {
        name: "Pro",
        price: 19.0,
        stripe_price_id: price_ids[:pro],
        popular: true,
        features: [
          "All free features",
          "Advanced features",
          "Priority support",
          "Cancel anytime"
        ]
      },
      price_ids[:max] => {
        name: "Max",
        price: 49.0,
        stripe_price_id: price_ids[:max],
        popular: false,
        features: [
          "All Pro features",
          "Premium features",
          "Dedicated support",
          "Cancel anytime"
        ]
      }
    }
  end

  def self.all_plans
    plan_config.map do |id, config|
      {
        id: id,
        **config
      }
    end
  end

  def self.paid_plans
    all_plans.reject { |plan| plan[:id] == "free" }
  end

  def self.find_plan(id)
    config = plan_config[id.to_s]
    return nil unless config

    {
      id: id,
      **config
    }
  end

  def self.plan_name(plan_id)
    find_plan(plan_id)&.dig(:name) || "Free"
  end

  def self.for_frontend
    all_plans.map do |plan|
      {
        id: plan[:id],
        name: plan[:name],
        price: plan[:price],
        popular: plan[:popular],
        features: plan[:features]
      }
    end
  end

  # Credits system - determines monthly article generation credits per plan
  def self.free_tier_credits
    3
  end

  def self.credits_for_plan(price_id)
    return free_tier_credits if price_id.nil? || price_id == "free"

    # Match against current environment's price IDs
    price_ids = current_price_ids

    case price_id
    when price_ids[:pro]
      10  # $19.99/mo = 10 articles
    when price_ids[:max]
      30  # $49.99/mo = 30 articles
    else
      free_tier_credits  # Default to free tier if unknown price_id
    end
  end
end
