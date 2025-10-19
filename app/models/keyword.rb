class Keyword < ApplicationRecord
  belongs_to :keyword_research
  has_one :article, dependent: :destroy
  has_one :project, through: :keyword_research

  validates :keyword, presence: true

  enum :generation_status, {
    not_started: 0,
    queued: 1,
    generating: 2,
    completed: 3,
    failed: 4
  }

  scope :published, -> { where(published: true) }
  scope :unpublished, -> { where(published: false) }
  scope :by_opportunity, -> { order(opportunity: :desc) }
  scope :starred, -> { where(starred: true) }
  scope :recommended, -> { where("opportunity >= ?", 70) }
  scope :queued_for_generation, -> { where(queued_for_generation: true) }
  scope :scheduled, -> { where.not(scheduled_for: nil) }

  def easy_win?
    opportunity >= 70
  end

  def medium_opportunity?
    opportunity >= 50 && opportunity < 70
  end

  def difficulty_level
    return "Low" if difficulty < 33
    return "Medium" if difficulty < 66
    "High"
  end

  def difficulty_badge_color
    return "🟢" if difficulty < 33  # Easy/Low
    return "🟡" if difficulty < 66  # Medium
    "🔴"  # Hard/High
  end
end
