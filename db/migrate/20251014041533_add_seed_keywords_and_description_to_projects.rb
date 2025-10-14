class AddSeedKeywordsAndDescriptionToProjects < ActiveRecord::Migration[8.0]
  def change
    add_column :projects, :seed_keywords, :jsonb, default: []
    add_column :projects, :description, :text
    add_column :projects, :domain_analysis, :jsonb
  end
end
