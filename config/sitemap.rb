SitemapGenerator::Sitemap.default_host = ENV.fetch('APP_URL', 'https://example.com')
SitemapGenerator::Sitemap.create do
  add '/', changefreq: 'weekly', priority: 0.8
  add '/pricing', changefreq: 'monthly'
end
