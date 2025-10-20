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

  # Clustering scopes
  scope :cluster_representatives, -> { where(is_cluster_representative: true) }
  scope :in_cluster, ->(cluster_id) { where(cluster_id: cluster_id) }
  scope :unclustered, -> { where(cluster_id: nil) }

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

  # Clustering methods

  # Check if this keyword is part of a cluster
  def clustered?
    cluster_id.present?
  end

  # Get all keywords in this keyword's cluster (excluding self)
  def cluster_siblings
    return Keyword.none unless cluster_id.present?
    Keyword.in_cluster(cluster_id).where.not(id: id)
  end

  # Get the representative keyword for this cluster
  def cluster_representative
    return self if is_cluster_representative?
    return nil unless cluster_id.present?
    Keyword.find_by(cluster_id: cluster_id, is_cluster_representative: true)
  end

  # Get all keywords in this cluster (including self)
  def cluster_members
    return Keyword.where(id: id) unless cluster_id.present?
    Keyword.in_cluster(cluster_id)
  end
end
