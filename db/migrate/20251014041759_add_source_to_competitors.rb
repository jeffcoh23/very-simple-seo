class AddSourceToCompetitors < ActiveRecord::Migration[8.0]
  def change
    add_column :competitors, :source, :string, default: 'manual'
  end
end
