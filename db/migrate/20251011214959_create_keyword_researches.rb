class CreateKeywordResearches < ActiveRecord::Migration[8.0]
  def change
    create_table :keyword_researches do |t|
      t.references :project, null: false, foreign_key: true
      t.integer :status, default: 0, null: false
      t.text :seed_keywords, array: true, default: []
      t.integer :total_keywords_found
      t.datetime :started_at
      t.datetime :completed_at
      t.text :error_message

      t.timestamps
    end

    add_index :keyword_researches, :status
  end
end
