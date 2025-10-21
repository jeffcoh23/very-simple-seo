# app/models/voice_profile.rb
class VoiceProfile < ApplicationRecord
  belongs_to :user

  # Validations
  validates :name, presence: true
  validates :description, presence: true
  validate :user_cannot_have_multiple_defaults, if: :is_default?

  # Callbacks
  before_save :ensure_single_default, if: :is_default_changed?

  # Methods
  def to_prompt_instruction
    parts = [description]
    parts << "\n\nExample writing style:\n#{sample_text}" if sample_text.present?
    parts.join
  end

  private

  def user_cannot_have_multiple_defaults
    return unless user_id.present?

    existing_default = VoiceProfile.where(user_id: user_id, is_default: true)
      .where.not(id: id)
      .exists?

    errors.add(:is_default, "user already has a default voice profile") if existing_default
  end

  def ensure_single_default
    return unless is_default? && user_id.present?

    # Un-set any other default for this user
    VoiceProfile.where(user_id: user_id, is_default: true)
      .where.not(id: id)
      .update_all(is_default: false)
  end
end
