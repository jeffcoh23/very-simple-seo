# app/models/voice_profile.rb
class VoiceProfile < ApplicationRecord
  belongs_to :user
  has_many :articles, dependent: :nullify

  # Validations
  validates :name, presence: true
  validates :description, presence: true

  # Callbacks
  before_save :ensure_single_default, if: :is_default?

  # Methods
  def to_prompt_instruction
    parts = [ description ]
    parts << "\n\nExample writing style:\n#{sample_text}" if sample_text.present?
    parts.join
  end

  private

  def ensure_single_default
    return unless is_default? && user_id.present?

    # Un-set any other default for this user
    VoiceProfile.where(user_id: user_id, is_default: true)
      .where.not(id: id)
      .update_all(is_default: false)
  end
end
