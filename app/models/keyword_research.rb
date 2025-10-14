class KeywordResearch < ApplicationRecord
  belongs_to :project
  has_many :keywords, dependent: :destroy

  enum :status, { pending: 0, processing: 1, completed: 2, failed: 3 }

  def retry!
    update!(status: :pending, error_message: nil, progress_log: [])
    KeywordResearchJob.perform_later(id)
  end

  def add_progress_log(message, indent: 0)
    self.progress_log ||= []
    self.progress_log << { time: Time.current.to_s, message: message, indent: indent }
    save!
  end
end
