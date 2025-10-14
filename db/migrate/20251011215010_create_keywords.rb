class CreateKeywords < ActiveRecord::Migration[8.0]
  def change
    create_table :keywords do |t|
      t.references :keyword_research, null: false, foreign_key: true
      t.string :keyword, null: false
      t.integer :volume
      t.integer :difficulty
      t.integer :opportunity
      t.decimal :cpc, precision: 10, scale: 2
      t.string :intent
      t.text :sources, array: true, default: []
      t.boolean :published, default: false
      t.boolean :starred, default: false
      t.boolean :queued_for_generation, default: false
      t.datetime :scheduled_for
      t.integer :generation_status, default: 0, null: false

      t.timestamps
    end

    add_index :keywords, :opportunity
    add_index :keywords, :published
    add_index :keywords, :starred
    add_index :keywords, :queued_for_generation
    add_index :keywords, :generation_status
  end
end
