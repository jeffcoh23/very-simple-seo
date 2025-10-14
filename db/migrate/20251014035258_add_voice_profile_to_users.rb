class AddVoiceProfileToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :voice_profile, :text
  end
end
