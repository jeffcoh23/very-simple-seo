class AddProgressLogToKeywordResearches < ActiveRecord::Migration[8.0]
  def change
    add_column :keyword_researches, :progress_log, :jsonb, default: []
  end
end
