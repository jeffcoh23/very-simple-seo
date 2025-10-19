class RegistrationsController < ApplicationController
  allow_unauthenticated_access only: [ :new, :create ]
  before_action :redirect_if_authenticated, only: [ :new ]

  def new
    plan = params[:plan] || "free"
    render inertia: "Auth/Signup", props: {
      plan: plan,
      plans: PlansService.for_frontend
    }
  end

  def create
    user = User.new(user_params)
    selected_plan = params[:plan] || "free"

    if user.save
      # Send email verification
      EmailVerificationMailer.verify(user).deliver_later

      start_new_session_for user

      # If paid plan selected, redirect to checkout
      if selected_plan != "free"
        inertia_location subscribe_path(price_id: selected_plan)
      else
        redirect_to "/app", notice: "Welcome! Please check your email to verify your account."
      end
    else
      flash.now[:alert] = user.errors.full_messages.to_sentence
      render inertia: "Auth/Signup", props: {
        plan: selected_plan,
        plans: PlansService.for_frontend,
        errors: user.errors.full_messages
      }, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotUnique => e
    # Handle duplicate email gracefully
    flash.now[:alert] = "An account with this email address already exists. Please sign in instead."
    render inertia: "Auth/Signup", props: {
      plan: selected_plan,
      plans: PlansService.for_frontend,
      errors: [ "Email address has already been taken" ]
    }, status: :unprocessable_entity
  end

  private

  def user_params
    params.permit(:first_name, :last_name, :email_address, :password, :password_confirmation)
  end

  def redirect_if_authenticated
    redirect_to "/app" if authenticated?
  end
end
