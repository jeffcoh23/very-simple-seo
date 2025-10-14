class Article < ApplicationRecord
  belongs_to :keyword
  belongs_to :project

  enum :status, { pending: 0, generating: 1, completed: 2, failed: 3 }

  validates :keyword_id, uniqueness: true # One article per keyword

  def retry!
    update!(status: :pending, error_message: nil)
    ArticleGenerationJob.perform_later(id)
  end

  def export_markdown
    content
  end

  def export_html
    # Use a markdown processor (e.g., kramdown)
    require 'kramdown'
    Kramdown::Document.new(content || "").to_html
  end
end
