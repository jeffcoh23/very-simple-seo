class AddTitleAndDescriptionToCompetitors < ActiveRecord::Migration[8.0]
  def change
    add_column :competitors, :title, :string
    add_column :competitors, :description, :text
  end
end
