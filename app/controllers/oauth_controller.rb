class OauthController < ApplicationController
  allow_unauthenticated_access

  def callback
    auth = request.env["omniauth.auth"]
    email = auth.dig("info", "email")
    first_name = auth.dig("info", "first_name") || auth.dig("info", "given_name") || "User"
    last_name = auth.dig("info", "last_name") || auth.dig("info", "family_name") || "User"
    provider = auth.provider
    uid = auth.uid

    # Extract plan from OAuth state parameter
    selected_plan = nil
    if params[:state].present?
      begin
        state_data = JSON.parse(params[:state])
        selected_plan = state_data["plan"]
      rescue JSON::ParserError => e
        Rails.logger.warn "Failed to parse OAuth state parameter: #{e.message}"
      end
    end

    user = User.find_or_initialize_by(email_address: email)

    if user.new_record?
      # New Google user
      user.first_name = first_name
      user.last_name = last_name
      user.password = SecureRandom.hex(24)
      user.password_confirmation = user.password
      user.email_verified_at = Time.current # Auto-verify Google emails
      user.oauth_provider = provider
      user.oauth_uid = uid
      user.save!

      start_new_session_for(user)

      # Handle plan selection
      if selected_plan && selected_plan != "free"
        plan_id = find_plan_id_by_name(selected_plan)
        if plan_id
          redirect_to subscribe_path(price_id: plan_id), notice: "Welcome! Account created with Google."
        else
          redirect_to "/app", notice: "Welcome! Account created with Google."
        end
      else
        redirect_to "/app", notice: "Welcome! Account created with Google."
      end
    else
      # Existing user - just sign them in
      start_new_session_for(user)
      redirect_to "/app", notice: "Signed in with Google"
    end
  end

  def failure
    redirect_to "/login", alert: "OAuth error"
  end

  private

  def find_plan_id_by_name(plan_name)
    return nil if plan_name.blank?

    plan = PlansService.all_plans.find { |p| p[:name].downcase == plan_name.downcase }
    plan&.dig(:id)
  end
end
