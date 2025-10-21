require "test_helper"

class SettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create_test_user
    sign_in(@user)

    # Destroy default voice profiles to avoid conflicts
    @user.voice_profiles.destroy_all

    # Create some voice profiles for testing
    @voice1 = @user.voice_profiles.create!(name: "Professional", description: "Professional tone", is_default: true)
    @voice2 = @user.voice_profiles.create!(name: "Casual", description: "Casual tone", is_default: false)
  end

  def sign_in(user)
    post "/sign_in", params: {
      email_address: user.email_address,
      password: "password123"
    }
  end

  # GET /settings
  test "should get settings page" do
    get "/settings"
    assert_response :success
  end

  test "should require authentication for settings" do
    delete "/sign_out"
    get "/settings"
    assert_redirected_to "/session/new"
  end

  # PATCH /settings - Profile Update
  test "should update profile information" do
    patch "/settings", params: {
      user: {
        first_name: "Updated",
        last_name: "Name"
      }
    }

    @user.reload
    assert_equal "Updated", @user.first_name
    assert_equal "Name", @user.last_name
    assert_redirected_to "/settings"
  end

  test "should handle profile update validation errors" do
    patch "/settings", params: {
      user: {
        first_name: "",
        last_name: ""
      }
    }

    @user.reload
    # Should not update with invalid data
    assert_equal "Test", @user.first_name
    assert_redirected_to "/settings"
  end

  # PATCH /settings - Password Update
  test "should update password with correct current_password" do
    patch "/settings", params: {
      current_password: "password123",
      user: {
        password: "newpassword123",
        password_confirmation: "newpassword123"
      }
    }

    assert_redirected_to "/settings"

    # Verify new password works
    delete "/sign_out"
    post "/sign_in", params: {
      email_address: @user.email_address,
      password: "newpassword123"
    }
    assert_response :redirect
  end

  test "should fail password update with incorrect current_password" do
    patch "/settings", params: {
      current_password: "wrongpassword",
      user: {
        password: "newpassword123",
        password_confirmation: "newpassword123"
      }
    }

    assert_redirected_to "/settings"

    # Verify old password still works
    delete "/sign_out"
    post "/sign_in", params: {
      email_address: @user.email_address,
      password: "password123"
    }
    assert_response :redirect
  end

  test "should fail password update with mismatched confirmation" do
    patch "/settings", params: {
      current_password: "password123",
      user: {
        password: "newpassword123",
        password_confirmation: "differentpassword"
      }
    }

    assert_redirected_to "/settings"
  end

  test "should prevent OAuth users from changing password" do
    oauth_user = User.create!(
      email_address: "oauth@example.com",
      password: "password123",
      password_confirmation: "password123",
      first_name: "OAuth",
      last_name: "User",
      email_verified_at: Time.current,
      oauth_provider: "google_oauth2",
      oauth_uid: "12345"
    )

    sign_in(oauth_user)

    patch "/settings", params: {
      current_password: "password123",
      user: {
        password: "newpassword123",
        password_confirmation: "newpassword123"
      }
    }

    assert_redirected_to "/settings"
  end

  # PATCH /settings - Voice Profiles (Nested Attributes)
  test "should create new voice profile via nested attributes" do
    assert_difference "VoiceProfile.count", 1 do
      patch "/settings", params: {
        user: {
          voice_profiles_attributes: [
            { name: "New Voice", description: "New voice description" }
          ]
        }
      }
    end

    new_voice = @user.voice_profiles.find_by(name: "New Voice")
    assert_not_nil new_voice
    assert_equal "New voice description", new_voice.description
    assert_redirected_to "/settings"
  end

  test "should update existing voice profile via nested attributes" do
    patch "/settings", params: {
      user: {
        voice_profiles_attributes: [
          { id: @voice1.id, name: "Updated Professional", description: "Updated description" }
        ]
      }
    }

    @voice1.reload
    assert_equal "Updated Professional", @voice1.name
    assert_equal "Updated description", @voice1.description
    assert_redirected_to "/settings"
  end

  test "should delete voice profile via nested attributes" do
    assert_difference "VoiceProfile.count", -1 do
      patch "/settings", params: {
        user: {
          voice_profiles_attributes: [
            { id: @voice2.id, _destroy: true }
          ]
        }
      }
    end

    assert_not VoiceProfile.exists?(@voice2.id)
    assert_redirected_to "/settings"
  end

  test "should handle multiple voice profile updates in single request" do
    voice3 = @user.voice_profiles.create!(name: "Formal", description: "Formal tone")

    patch "/settings", params: {
      user: {
        voice_profiles_attributes: [
          { id: @voice1.id, name: "Updated Voice 1", description: @voice1.description },
          { id: @voice2.id, name: @voice2.name, description: "Updated description 2" },
          { name: "Brand New Voice", description: "New description" }
        ]
      }
    }

    @voice1.reload
    @voice2.reload

    assert_equal "Updated Voice 1", @voice1.name
    assert_equal "Updated description 2", @voice2.description
    assert @user.voice_profiles.exists?(name: "Brand New Voice")
    assert_redirected_to "/settings"
  end

  # PATCH /settings - Set Default Voice
  test "should set voice as default via default_voice_id" do
    assert @voice1.is_default?
    assert_not @voice2.is_default?

    patch "/settings", params: {
      default_voice_id: @voice2.id
    }

    @voice1.reload
    @voice2.reload

    assert_not @voice1.is_default?
    assert @voice2.is_default?
    assert_redirected_to "/settings"
  end

  test "should handle invalid voice_id when setting default" do
    patch "/settings", params: {
      default_voice_id: 99999
    }

    assert_redirected_to "/settings"

    # Original default should still be default
    @voice1.reload
    assert @voice1.is_default?
  end

  test "should not allow setting another user's voice as default" do
    other_user = create_test_user
    other_voice = other_user.voice_profiles.create!(name: "Other Voice", description: "Other description")

    patch "/settings", params: {
      default_voice_id: other_voice.id
    }

    assert_redirected_to "/settings"

    # Should not have set the other user's voice as default
    assert_not @user.voice_profiles.exists?(id: other_voice.id)
  end

  # Authorization Tests
  test "should not update other user's settings" do
    other_user = create_test_user

    patch "/settings", params: {
      user: {
        first_name: "Hacked"
      }
    }

    other_user.reload
    # Should not have updated the other user
    assert_not_equal "Hacked", other_user.first_name
  end

  test "should not access other user's voice profiles" do
    other_user = create_test_user
    other_voice = other_user.voice_profiles.create!(name: "Other Voice", description: "Other description")

    # Try to update another user's voice
    patch "/settings", params: {
      user: {
        voice_profiles_attributes: [
          { id: other_voice.id, name: "Hacked Voice" }
        ]
      }
    }

    other_voice.reload
    # Should not have updated the other user's voice
    assert_equal "Other Voice", other_voice.name
  end
end
