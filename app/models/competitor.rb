class Competitor < ApplicationRecord
  belongs_to :project

  validates :domain, presence: true
end
