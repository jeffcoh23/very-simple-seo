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

  # Voice Profile Tests
  test "should have many voice_profiles" do
    user = create_test_user
    voice1 = user.voice_profiles.create!(name: "Test Voice 1", description: "Test tone 1")
    voice2 = user.voice_profiles.create!(name: "Test Voice 2", description: "Test tone 2")

    # User gets 7 default voices + 2 created = 9 total
    assert_equal 9, user.voice_profiles.count
    assert_includes user.voice_profiles, voice1
    assert_includes user.voice_profiles, voice2
  end

  test "should destroy associated voice_profiles when user is destroyed" do
    user = create_test_user
    user.voice_profiles.create!(name: "Test Voice", description: "Test description")

    # User has 7 default voices + 1 created = 8 total
    assert_difference "VoiceProfile.count", -8 do
      user.destroy
    end
  end

  test "should create default voice profiles after user creation" do
    # Create a new user (not using the test helper which might skip callbacks)
    user = User.create!(
      email_address: "newuser@example.com",
      password: "password123",
      password_confirmation: "password123",
      first_name: "New",
      last_name: "User",
      email_verified_at: Time.current
    )

    # Should have 7 default voice profiles
    assert_equal 7, user.voice_profiles.count

    # Check voice profile names
    voice_names = user.voice_profiles.pluck(:name)
    assert_includes voice_names, "Professional"
    assert_includes voice_names, "Casual"
    assert_includes voice_names, "Friendly"
    assert_includes voice_names, "Formal"
    assert_includes voice_names, "Technical"
    assert_includes voice_names, "Conversational"
    assert_includes voice_names, "Authoritative"
  end

  test "should have one default voice profile after creation" do
    user = User.create!(
      email_address: "newuser2@example.com",
      password: "password123",
      password_confirmation: "password123",
      first_name: "New",
      last_name: "User",
      email_verified_at: Time.current
    )

    default_voices = user.voice_profiles.where(is_default: true)
    assert_equal 1, default_voices.count
    assert_equal "Professional", default_voices.first.name
  end

  test "default_voice returns the voice marked as default" do
    user = create_test_user
    voice1 = user.voice_profiles.create!(name: "Voice 1", description: "Desc 1", is_default: false)
    voice2 = user.voice_profiles.create!(name: "Voice 2", description: "Desc 2", is_default: true)
    voice3 = user.voice_profiles.create!(name: "Voice 3", description: "Desc 3", is_default: false)

    assert_equal voice2, user.default_voice
  end

  test "default_voice returns first voice if none marked default" do
    user = create_test_user
    # Destroy all default voices to test fallback behavior
    user.voice_profiles.destroy_all

    voice1 = user.voice_profiles.create!(name: "AAA Voice", description: "AAA description", is_default: false)
    voice2 = user.voice_profiles.create!(name: "BBB Voice", description: "BBB description", is_default: false)

    # Neither is default, should return first
    assert_equal voice1, user.default_voice
  end

  test "default_voice returns nil if user has no voices" do
    user = create_test_user
    # Clear all voice profiles
    user.voice_profiles.destroy_all

    assert_nil user.default_voice
  end

  test "should accept nested attributes for voice_profiles" do
    user = create_test_user
    voice = user.voice_profiles.create!(name: "Original Name", description: "Original description")

    user.update!(
      voice_profiles_attributes: [
        { id: voice.id, name: "Updated Name" }
      ]
    )

    voice.reload
    assert_equal "Updated Name", voice.name
  end

  test "should allow destroying voice_profiles via nested attributes" do
    user = create_test_user
    voice = user.voice_profiles.create!(name: "To Delete", description: "To delete description")

    assert_difference "VoiceProfile.count", -1 do
      user.update!(
        voice_profiles_attributes: [
          { id: voice.id, _destroy: true }
        ]
      )
    end
  end
end
