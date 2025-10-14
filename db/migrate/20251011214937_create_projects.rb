class CreateProjects < ActiveRecord::Migration[8.0]
  def change
    create_table :projects do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.string :domain, null: false
      t.string :niche
      t.string :tone_of_voice
      t.jsonb :call_to_actions, default: []
      t.string :sitemap_url

      t.timestamps
    end
  end
end
