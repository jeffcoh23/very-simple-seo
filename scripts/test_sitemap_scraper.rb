#!/usr/bin/env ruby
# Test sitemap scraping on SignalLab

require_relative '../config/environment'

project = Project.find(25)

puts "=" * 80
puts "TESTING SITEMAP SCRAPER SERVICE"
puts "=" * 80
puts
puts "Project: #{project.name}"
puts "Domain: #{project.domain}"
puts "Sitemap URL: #{project.sitemap_url || 'Not configured (will try default)'}"
puts
puts "=" * 80
puts "RUNNING SITEMAP SCRAPER..."
puts "=" * 80
puts

service = SitemapScraperService.new(project)
result = service.perform

puts
puts "=" * 80
puts "RESULTS"
puts "=" * 80
puts

if result[:success]
  puts "✅ SUCCESS"
  puts
  puts "Discovery method: #{project.internal_content_index['discovery_method']}"
  puts "Pages discovered: #{result[:pages].size}"
  puts "Last scraped: #{project.internal_content_index['last_scraped']}"
  puts

  if result[:errors].any?
    puts "⚠️  Warnings:"
    result[:errors].each { |err| puts "  - #{err}" }
    puts
  end

  puts "DISCOVERED PAGES:"
  puts "-" * 80
  result[:pages].first(10).each_with_index do |page, i|
    puts "#{i+1}. #{page['title']}"
    puts "   URL: #{page['url']}"
    puts "   Meta: #{page['meta_description'][0..80]}..." if page['meta_description'].present?
    puts "   Headings: #{page['headings'].first(3).join(', ')}" if page['headings']&.any?
    puts
  end

  if result[:pages].size > 10
    puts "... and #{result[:pages].size - 10} more pages"
  end

  puts
  puts "=" * 80
  puts "FALLBACK STRATEGIES USED"
  puts "=" * 80
  puts

  case project.internal_content_index['discovery_method']
  when 'sitemap.xml'
    puts "✅ PRIMARY: Found sitemap.xml"
    puts "   This is the ideal scenario - site has a proper sitemap"
  when 'sitemap_index'
    puts "✅ GOOD: Found sitemap index (multiple sitemaps)"
    puts "   Site uses sitemap index - parsed first 5 sitemaps"
  when 'robots.txt'
    puts "⚠️  SECONDARY: Found sitemap via robots.txt"
    puts "   No sitemap.xml at default location, but robots.txt pointed to it"
  when 'common_paths'
    puts "⚠️  FALLBACK: No sitemap found - tried common paths"
    puts "   Discovered pages by checking /blog, /pricing, /features, etc."
    puts "   RECOMMENDATION: Add a sitemap.xml to your site for better discovery"
  else
    puts "❌ UNKNOWN method: #{project.internal_content_index['discovery_method']}"
  end

else
  puts "❌ FAILED"
  puts
  puts "Errors:"
  result[:errors].each { |err| puts "  - #{err}" }
  puts
  puts "=" * 80
  puts "TROUBLESHOOTING"
  puts "=" * 80
  puts
  puts "Common issues:"
  puts "1. No sitemap.xml exists"
  puts "   → Solution: Add a sitemap to your site"
  puts "   → Fallback: We'll try common paths (/blog, /pricing, etc.)"
  puts
  puts "2. Sitemap is password-protected or requires auth"
  puts "   → Solution: Make sitemap publicly accessible"
  puts
  puts "3. Site is down or blocking requests"
  puts "   → Check: #{project.domain} is accessible"
  puts
  puts "4. Invalid sitemap format"
  puts "   → Validate: Use https://www.xml-sitemaps.com/validate-xml-sitemap.html"
end

puts
puts "=" * 80
puts "NEXT STEPS"
puts "=" * 80
puts

if result[:success] && result[:pages].any?
  puts "✅ Ready to generate articles with internal links!"
  puts
  puts "The next article generation will automatically:"
  puts "  - Suggest 3-5 internal links to your actual pages"
  puts "  - Use REAL URLs from your live site"
  puts "  - Link to relevant pricing/feature/blog pages"
  puts
  puts "To refresh content (recommended monthly):"
  puts "  SitemapScraperService.new(project).perform"
elsif result[:success] && result[:pages].empty?
  puts "⚠️  No pages discovered"
  puts
  puts "Options:"
  puts "  1. Add sitemap.xml to your site (recommended)"
  puts "  2. Add common pages: /blog, /pricing, /features"
  puts "  3. Configure custom sitemap URL in project settings"
else
  puts "❌ Scraping failed"
  puts
  puts "Check errors above and try again"
end

puts "=" * 80
