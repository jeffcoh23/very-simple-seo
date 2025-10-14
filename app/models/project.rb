class Project < ApplicationRecord
  belongs_to :user
  has_many :competitors, dependent: :destroy
  has_many :keyword_researches, dependent: :destroy
  has_many :keywords, through: :keyword_researches
  has_many :articles, dependent: :destroy

  validates :name, presence: true
  validates :domain, presence: true, format: { with: URI::regexp(%w[http https]) }

  # Tone of voice options
  TONE_OPTIONS = [
    "Professional",
    "Casual",
    "Friendly",
    "Authoritative",
    "Conversational"
  ].freeze

  def default_cta
    call_to_actions&.first
  end
end
