class CreateCompetitors < ActiveRecord::Migration[8.0]
  def change
    create_table :competitors do |t|
      t.references :project, null: false, foreign_key: true
      t.string :domain, null: false
      t.boolean :auto_detected, default: false

      t.timestamps
    end
  end
end
