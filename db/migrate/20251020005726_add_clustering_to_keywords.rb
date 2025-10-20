class AddClusteringToKeywords < ActiveRecord::Migration[8.0]
  def change
    add_column :keywords, :cluster_id, :integer
    add_column :keywords, :is_cluster_representative, :boolean, default: false
    add_column :keywords, :cluster_size, :integer, default: 1
    add_column :keywords, :cluster_keywords, :jsonb, default: []

    add_index :keywords, :cluster_id
  end
end
