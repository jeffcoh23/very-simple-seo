class EmailVerificationController < ApplicationController
  allow_unauthenticated_access only: [ :show ]

  def show
    if user = User.find_by_token_for(:email_verification, params[:token])
      user.verify_email!
      if authenticated? && current_user == user
        redirect_to "/app", notice: "Email verified successfully!"
      else
        redirect_to login_path, notice: "Email verified! Please sign in to continue."
      end
    else
      redirect_to root_path, alert: "Email verification link is invalid or has expired."
    end
  end

  def create
    EmailVerificationMailer.verify(current_user).deliver_later
    redirect_to "/app", notice: "Verification email sent. Please check your email."
  end
end
