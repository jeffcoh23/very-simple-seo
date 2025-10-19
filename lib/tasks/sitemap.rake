namespace :sitemap do
  desc "Generate sitemap"
  task generate: :environment do
    require "sitemap_generator"
    SitemapGenerator::Interpreter.run
  end
end
