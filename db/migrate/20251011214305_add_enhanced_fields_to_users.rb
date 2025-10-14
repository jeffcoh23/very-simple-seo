class AddEnhancedFieldsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :first_name, :string
    add_column :users, :last_name, :string
    add_column :users, :email_verified_at, :datetime
    add_column :users, :oauth_provider, :string
    add_column :users, :oauth_uid, :string
  end
end
