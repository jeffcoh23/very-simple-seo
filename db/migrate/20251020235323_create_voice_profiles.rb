class CreateVoiceProfiles < ActiveRecord::Migration[8.0]
  def change
    create_table :voice_profiles do |t|
      t.references :user, foreign_key: true, null: true  # null for system defaults
      t.string :name, null: false
      t.text :description, null: false
      t.text :sample_text
      t.boolean :is_default, default: false, null: false
      t.boolean :is_system, default: false, null: false

      t.timestamps
    end

    add_index :voice_profiles, [:user_id, :is_default]
    add_index :voice_profiles, :is_system
  end
end
