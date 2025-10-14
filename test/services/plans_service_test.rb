require "test_helper"

class PlansServiceTest < ActiveSupport::TestCase
  test "free_tier_credits returns 3" do
    assert_equal 3, PlansService.free_tier_credits
  end

  test "credits_for_plan returns free tier credits for nil" do
    assert_equal 3, PlansService.credits_for_plan(nil)
  end

  test "credits_for_plan returns free tier credits for 'free'" do
    assert_equal 3, PlansService.credits_for_plan("free")
  end

  test "credits_for_plan returns 10 for Pro plan" do
    # Get the actual Pro price ID from the service
    pro_price_id = PlansService.current_price_ids[:pro]
    assert_equal 10, PlansService.credits_for_plan(pro_price_id)
  end

  test "credits_for_plan returns 30 for Max plan" do
    # Get the actual Max price ID from the service
    max_price_id = PlansService.current_price_ids[:max]
    assert_equal 30, PlansService.credits_for_plan(max_price_id)
  end

  test "credits_for_plan returns free tier credits for unknown plan" do
    assert_equal 3, PlansService.credits_for_plan("unknown_price_id")
  end

  test "for_frontend returns array of plans" do
    plans = PlansService.for_frontend

    assert_kind_of Array, plans
    assert plans.length >= 3 # Should have at least Free, Pro, Max

    # Check structure of first plan
    plan = plans.first
    assert plan.key?(:id)
    assert plan.key?(:name)
    assert plan.key?(:price)
  end

  test "current_price_ids returns hash with plan symbols" do
    price_ids = PlansService.current_price_ids

    assert_kind_of Hash, price_ids
    assert price_ids.key?(:pro)
    assert price_ids.key?(:max)
  end
end
