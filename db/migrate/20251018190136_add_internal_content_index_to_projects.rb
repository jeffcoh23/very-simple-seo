class AddInternalContentIndexToProjects < ActiveRecord::Migration[8.0]
  def change
    add_column :projects, :internal_content_index, :jsonb, default: {}
    add_index :projects, :internal_content_index, using: :gin
  end
end
