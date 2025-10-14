class CreateArticles < ActiveRecord::Migration[8.0]
  def change
    create_table :articles do |t|
      t.references :keyword, null: false, foreign_key: true, index: { unique: true }
      t.references :project, null: false, foreign_key: true
      t.string :title
      t.string :meta_description
      t.text :content
      t.jsonb :outline
      t.jsonb :serp_data
      t.integer :status, default: 0, null: false
      t.integer :word_count
      t.integer :target_word_count
      t.decimal :generation_cost, precision: 10, scale: 4
      t.datetime :started_at
      t.datetime :completed_at
      t.text :error_message

      t.timestamps
    end

    add_index :articles, :status
  end
end
