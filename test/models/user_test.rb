require "test_helper"

class UserTest < ActiveSupport::TestCase
  # Validations
  test "should validate presence of email_address" do
    user = User.new(password: "password123")
    assert_not user.valid?
    assert_includes user.errors[:email_address], "can't be blank"
  end

  test "should validate uniqueness of email_address" do
    create_test_user(email_address: "test@example.com")
    user = User.new(email_address: "test@example.com", password: "password123")
    assert_not user.valid?
    assert_includes user.errors[:email_address], "has already been taken"
  end

  test "should validate email format" do
    user = User.new(email_address: "invalid-email", password: "password123")
    assert_not user.valid?
    assert_includes user.errors[:email_address], "is invalid"
  end

  test "should validate password length" do
    user = User.new(email_address: "test@example.com", password: "short")
    assert_not user.valid?
    assert_includes user.errors[:password], "is too short (minimum is 8 characters)"
  end

  # Credits system
  test "has_credits? returns true when credits > 0" do
    user = create_test_user
    user.update!(credits: 5)
    assert user.has_credits?
  end

  test "has_credits? returns false when credits = 0" do
    user = create_test_user
    user.update!(credits: 0)
    assert_not user.has_credits?
  end

  test "deduct_credit! decrements credits by 1" do
    user = create_test_user
    user.update!(credits: 5)

    assert_difference "user.credits", -1 do
      user.deduct_credit!
      user.reload
    end
  end

  test "deduct_credit! returns false when no credits" do
    user = create_test_user
    user.update!(credits: 0)

    result = user.deduct_credit!
    assert_not result
  end

  test "add_credits! increments credits" do
    user = create_test_user
    user.update!(credits: 3)

    user.add_credits!(5)
    assert_equal 8, user.reload.credits
  end

  # Plan helpers
  test "free_plan? returns true for free users" do
    user = create_test_user
    assert user.free_plan?
  end

  test "paid_plan? returns false for free users" do
    user = create_test_user
    assert_not user.paid_plan?
  end

  test "plan_name returns Free for free users" do
    user = create_test_user
    assert_equal "Free", user.plan_name
  end

  test "job_priority returns 5 for free users" do
    user = create_test_user
    assert_equal 5, user.job_priority
  end

  # Associations
  test "should have many projects" do
    user = create_test_user
    project1 = user.projects.create!(name: "Project 1", domain: "https://example1.com")
    project2 = user.projects.create!(name: "Project 2", domain: "https://example2.com")

    assert_equal 2, user.projects.count
    assert_includes user.projects, project1
    assert_includes user.projects, project2
  end

  test "should destroy associated projects when user is destroyed" do
    user = create_test_user
    project = user.projects.create!(name: "Test Project", domain: "https://example.com")

    assert_difference "Project.count", -1 do
      user.destroy
    end
  end
end
