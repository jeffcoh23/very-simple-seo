class SettingsController < ApplicationController
  # GET /settings
  def show
    @voice_profiles = current_user.voice_profiles.order(is_default: :desc, name: :asc)
    sub = current_user&.pay_subscriptions&.active&.last

    render inertia: "App/Settings/Index", props: {
      user: user_props,
      voice_profiles: @voice_profiles.map { |v| voice_profile_props(v) },
      subscription: sub && {
        status: sub.status,
        plan: sub.name,
        on_grace_period: sub.on_grace_period?,
        ends_at: sub.ends_at
      },
      routes: settings_routes
    }
  end

  # PATCH /settings
  def update
    # Handle password change (requires current password verification)
    if params[:current_password].present?
      return handle_password_update
    end

    # Handle setting default voice
    if params[:default_voice_id].present?
      return handle_default_voice_update
    end

    # Handle profile and voice profiles update
    if current_user.update(settings_params)
      redirect_to settings_path, notice: "Settings updated successfully"
    else
      redirect_to settings_path, alert: current_user.errors.full_messages.to_sentence
    end
  end

  private

  def handle_password_update
    # OAuth users can't change password
    unless current_user.can_login_with_password?
      redirect_to settings_path, alert: "OAuth users cannot change password"
      return
    end

    # Verify current password
    unless current_user.authenticate(params[:current_password])
      redirect_to settings_path, alert: "Current password is incorrect"
      return
    end

    # Update password
    if current_user.update(password_params)
      redirect_to settings_path, notice: "Password updated successfully"
    else
      redirect_to settings_path, alert: current_user.errors.full_messages.to_sentence
    end
  end

  def handle_default_voice_update
    voice_profile = current_user.voice_profiles.find(params[:default_voice_id])

    # Update all user voices to not be default
    current_user.voice_profiles.update_all(is_default: false)

    # Set this one as default
    voice_profile.update!(is_default: true)

    redirect_to settings_path, notice: "Default voice updated successfully"
  rescue ActiveRecord::RecordNotFound
    redirect_to settings_path, alert: "Voice profile not found"
  end

  def settings_params
    params.require(:user).permit(
      :first_name,
      :last_name,
      :email_address,
      voice_profiles_attributes: [:id, :name, :description, :is_default, :_destroy]
    )
  end

  def password_params
    params.require(:user).permit(:password, :password_confirmation)
  end

  def user_props
    {
      id: current_user.id,
      first_name: current_user.first_name,
      last_name: current_user.last_name,
      email: current_user.email,
      full_name: current_user.full_name,
      initials: current_user.initials,
      plan_name: current_user.plan_name,
      oauth_user: current_user.oauth_user?,
      can_change_password: current_user.can_login_with_password?
    }
  end

  def voice_profile_props(voice)
    {
      id: voice.id,
      name: voice.name,
      description: voice.description,
      sample_text: voice.sample_text,
      is_default: voice.is_default
    }
  end

  def settings_routes
    {
      settings: settings_path,
      update_settings: settings_path  # Same path, PATCH method
    }
  end
end
