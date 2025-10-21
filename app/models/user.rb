class User < ApplicationRecord
pay_customer default_payment_processor: :stripe
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :projects, dependent: :destroy
  has_many :voice_profiles, dependent: :destroy

  accepts_nested_attributes_for :voice_profiles, allow_destroy: true

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  # Callbacks
  after_create :create_default_voice_profiles

# Validations
validates :first_name, presence: true
validates :last_name, presence: true
validates :email_address, presence: true, uniqueness: { case_sensitive: false }, format: { with: URI::MailTo::EMAIL_REGEXP }
validates :password, length: { minimum: 8 }, if: :password_required?

# Aliases
alias_attribute :email, :email_address

# Identity helpers
def full_name
  "#{first_name} #{last_name}".strip
end

def initials
  "#{first_name&.first}#{last_name&.first}".upcase
end

# Email verification (Rails 8 built-in token system)
generates_token_for :email_verification, expires_in: 3.days do
  email_address
end

def email_verified?
  email_verified_at.present?
end

def verify_email!
  update!(email_verified_at: Time.current)
end
alias_method :confirm!, :verify_email!

# OAuth authentication helpers
def oauth_user?
  oauth_provider.present?
end

def google_user?
  oauth_provider == "google_oauth2"
end

def regular_user?
  !oauth_user?
end

def can_login_with_password?
  regular_user?
end

# Subscription helpers
def plan_name
  active_subscription = pay_subscriptions.active.last
  return subscription_plan_name(active_subscription) if active_subscription
  "Free"
end

def current_subscription
  pay_subscriptions.active.last
end

def subscription_active?
  current_subscription.present?
end

def free_plan?
  plan_name == "Free"
end

def paid_plan?
  !free_plan?
end

# Job priority (paid users get higher priority)
def job_priority
  paid_plan? ? 10 : 5
end

# Credits management
def has_credits?
  credits > 0
end

def deduct_credit!
  return false unless has_credits?
  decrement!(:credits)
  true
end

def add_credits!(amount)
  increment!(:credits, amount)
end

def reset_credits_to_plan!
  update!(credits: PlansService.credits_for_plan(current_subscription&.processor_plan))
end

# Voice profile helpers
def default_voice
  voice_profiles.find_by(is_default: true) || voice_profiles.first
end

private

def password_required?
  return true if new_record?
  password.present? || password_confirmation.present?
end

def subscription_plan_name(subscription)
  PlansService.plan_name(subscription&.processor_plan)
end

def create_default_voice_profiles
  config = YAML.load_file(Rails.root.join("config", "voice_profiles.yml"))
  default_voices = config["default_voices"]

  default_voices.each do |voice_data|
    voice_profiles.create!(
      name: voice_data["name"],
      description: voice_data["description"],
      is_default: voice_data["is_default"],
      is_system: false
    )
  end
end
end
