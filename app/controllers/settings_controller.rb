class SettingsController < ApplicationController
  def show
    sub = current_user&.pay_subscriptions&.active&.last
    render inertia: "App/Settings", props: {
      user: {
        id: current_user.id,
        email_address: current_user.email_address,
        first_name: current_user.first_name,
        last_name: current_user.last_name,
        voice_profile: current_user.voice_profile
      },
      subscription: sub && {
        status: sub.status,
        plan: sub.name,
        on_grace_period: sub.on_grace_period?,
        ends_at: sub.ends_at
      }
    }
  end

  def update_profile
    if current_user.update(profile_params)
      redirect_to "/settings", notice: "Profile updated"
    else
      redirect_to "/settings", alert: current_user.errors.full_messages.to_sentence
    end
  end

  def update_password
    if current_user.authenticate(params[:current_password])
      if current_user.update(password_params)
        redirect_to "/settings", notice: "Password updated"
      else
        redirect_to "/settings", alert: current_user.errors.full_messages.to_sentence
      end
    else
      redirect_to "/settings", alert: "Current password is incorrect"
    end
  end

  private

  def profile_params
    params.permit(:first_name, :last_name, :voice_profile)
  end

  def password_params
    params.permit(:password, :password_confirmation)
  end
end
