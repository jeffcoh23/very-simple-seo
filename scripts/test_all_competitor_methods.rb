#!/usr/bin/env ruby
# scripts/test_all_competitor_methods.rb
# Test ALL competitor discovery methods to find the best one

require_relative '../config/environment'

domain = "https://validatorai.com"

puts "\n" + "="*80
puts "COMPREHENSIVE COMPETITOR DISCOVERY TEST"
puts "Domain: #{domain}"
puts "="*80

# Get domain data
puts "\nAnalyzing domain..."
analyzer = DomainAnalysisService.new(domain)
domain_data = analyzer.analyze

puts "  Title: #{domain_data[:title]}"
puts "  Description: #{domain_data[:meta_description]}"
puts "  H1s: #{domain_data[:h1s]&.first(3)&.join(', ')}"

# ============================================================================
# METHOD 1: OLD APPROACH - Google Search with smart query building
# ============================================================================
puts "\n" + "="*80
puts "METHOD 1: OLD GOOGLE SEARCH (smart query from H1s/title)"
puts "="*80

# Build search query the OLD way (from commit c875b62)
raw_topic = domain_data[:h1s]&.first || domain_data[:title] || ""
topic = raw_topic.split('|').first.strip

generic_niches = %w[saas software app platform tool service business]
niche = nil

search_term = if niche.present? && !generic_niches.include?(niche.downcase)
  niche
else
  topic
end

if search_term.split.size < 2
  search_term = domain_data[:h2s]&.first || domain_data[:meta_description] || search_term
  search_term = search_term.split(/[.|,]/).first.strip
end

puts "Search query: '#{search_term}'"

# Use SerpResearchService like the old code did
scraper = SerpResearchService.new(search_term)
google_results = scraper.search_results_only

puts "Raw Google results: #{google_results.size}"

# Filter out own domain
user_domain_host = URI(domain).host.gsub(/^www\./, '')
google_competitors = google_results.map do |result|
  next unless result[:url]

  uri = URI(result[:url])
  host = uri.host.gsub(/^www\./, '')
  domain_str = "#{uri.scheme}://#{uri.host}"

  next if host == user_domain_host

  {
    domain: domain_str.gsub(%r{^https?://}, '').gsub(/^www\./, ''),
    title: result[:title],
    description: result[:snippet]
  }
end.compact.uniq { |c| c[:domain] }

puts "\nGoogle Search Results: #{google_competitors.size} competitors"
google_competitors.first(20).each_with_index do |comp, i|
  puts "  #{i+1}. #{comp[:domain]}"
  puts "     #{comp[:title]}"
end

# ============================================================================
# METHOD 2: PURE GROUNDING (current approach)
# ============================================================================
puts "\n" + "="*80
puts "METHOD 2: PURE GOOGLE GROUNDING (current)"
puts "="*80

grounding = GoogleGroundingService.new

my_title = domain_data[:title] || domain
my_description = domain_data[:meta_description] || ""

query = <<~QUERY
  Search the web to find direct competitor tools for this business.

  MY BUSINESS:
  Title: #{my_title}
  Description: #{my_description}
  Website: #{domain}

  Your job: Find direct competitors.

  FILTERING CRITERIA - Must pass ALL tests:
  1. Same primary job - customers would use THIS instead of my business for the SAME task?
  2. Same product category - not adjacent/related categories
  3. Dedicated tool - not general platforms
  4. Actual software - not blogs/news/content sites

  For each competitor you find:
  - Research the domain to verify it's a real competitor
  - Return domain (without https://), title, and what they do

  Return ONLY valid JSON array of competitors:
  [
    {
      "domain": "competitor.com",
      "title": "Company Name",
      "description": "What they actually do"
    }
  ]

  Be strict - only include clear matches that pass all 4 tests.
  Find as many as you can (aim for 10-20+ if they exist).
QUERY

json_structure = [{domain: "competitor.com", title: "Name", description: "What they do"}].to_json
result = grounding.search_json(query, json_structure_hint: json_structure)

grounding_competitors = []

if result[:success]
  puts "\nGrounding used #{result[:grounding_metadata][:sources_count]} sources"

  data = result[:data]
  competitors_array = case data
  when Array
    data
  when Hash
    data["competitors"] || []
  else
    []
  end

  grounding_competitors = competitors_array.map do |c|
    domain_str = c["domain"] || c["url"]
    next unless domain_str

    domain_str = domain_str.to_s.strip
                 .gsub(%r{^https?://}, '')
                 .gsub(%r{^www\.}, '')
                 .gsub(%r{/$}, '')
                 .split('/').first
                 .downcase

    next if domain_str.empty? || !domain_str.include?('.')

    {
      domain: domain_str,
      title: c["title"] || c["name"] || domain_str.split('.').first.capitalize,
      description: c["description"] || c["what_they_do"] || ""
    }
  end.compact

  puts "\nGrounding Results: #{grounding_competitors.size} competitors"
  grounding_competitors.each_with_index do |comp, i|
    puts "  #{i+1}. #{comp[:domain]}"
    puts "     #{comp[:title]}"
    puts "     #{comp[:description]}"
  end
else
  puts "\nGrounding failed: #{result[:error]}"
end

# ============================================================================
# QUALITY ANALYSIS
# ============================================================================
puts "\n" + "="*80
puts "QUALITY ANALYSIS"
puts "="*80

# Define obviously bad domains
bad_patterns = [
  'reddit.com', 'medium.com', 'quora.com', 'stackoverflow.com',
  'news.ycombinator.com', 'facebook.com', 'twitter.com', 'linkedin.com',
  'youtube.com', 'techcrunch.com', 'forbes.com', 'wired.com',
  'g2.com', 'capterra.com', 'trustpilot.com', 'producthunt.com',
  'alternativeto.net', 'crunchbase.com', 'github.com', 'webcatalog.io',
  'dhiwise.com', 'nerdynav.com', 'aiforbusinesses.com', 'futurepedia.io',
  'pineapplebuilder.com', 'siteefy.com', 'theresanaiforthat.com',
  '10web.io', 'relay.app'
]

def is_bad?(domain, bad_patterns)
  bad_patterns.any? { |pattern| domain.include?(pattern) }
end

google_bad = google_competitors.count { |c| is_bad?(c[:domain], bad_patterns) }
google_good = google_competitors.size - google_bad

grounding_bad = grounding_competitors.count { |c| is_bad?(c[:domain], bad_patterns) }
grounding_good = grounding_competitors.size - grounding_bad

puts "\nGoogle Search:"
puts "  Total: #{google_competitors.size}"
puts "  Good (actual tools): #{google_good} (#{(google_good.to_f / google_competitors.size * 100).round(1)}%)"
puts "  Bad (review/blog sites): #{google_bad} (#{(google_bad.to_f / google_competitors.size * 100).round(1)}%)"

puts "\nGrounding:"
puts "  Total: #{grounding_competitors.size}"
puts "  Good (actual tools): #{grounding_good} (#{(grounding_good.to_f / grounding_competitors.size * 100).round(1)}%)"
puts "  Bad (review/blog sites): #{grounding_bad} (#{(grounding_bad.to_f / grounding_competitors.size * 100).round(1)}%)"

# Show bad competitors from each method
puts "\n--- Google Search: BAD competitors (review/blog sites) ---"
google_competitors.select { |c| is_bad?(c[:domain], bad_patterns) }.each do |comp|
  puts "  ❌ #{comp[:domain]} - #{comp[:title]}"
end

puts "\n--- Grounding: BAD competitors (if any) ---"
grounding_bad_list = grounding_competitors.select { |c| is_bad?(c[:domain], bad_patterns) }
if grounding_bad_list.empty?
  puts "  ✅ None! All competitors are actual tools."
else
  grounding_bad_list.each do |comp|
    puts "  ❌ #{comp[:domain]} - #{comp[:title]}"
  end
end

# Show overlap
puts "\n--- Overlap between methods ---"
google_domains = google_competitors.map { |c| c[:domain] }
grounding_domains = grounding_competitors.map { |c| c[:domain] }
overlap = (google_domains & grounding_domains)

puts "Shared competitors: #{overlap.size}"
overlap.each { |d| puts "  - #{d}" }

# Show unique to each
google_only = google_domains - grounding_domains
grounding_only = grounding_domains - google_domains

puts "\nGoogle-only (#{google_only.size}):"
google_only.first(15).each { |d| puts "  - #{d}" }

puts "\nGrounding-only (#{grounding_only.size}):"
grounding_only.each { |d| puts "  - #{d}" }

puts "\n" + "="*80
puts "RECOMMENDATION"
puts "="*80

if grounding_good > google_good
  puts "✅ Use GROUNDING - finds more actual competitor tools"
  puts "   Grounding: #{grounding_good} good competitors"
  puts "   Google: #{google_good} good competitors"
elsif google_good > grounding_good
  puts "✅ Use GOOGLE SEARCH - finds more actual competitor tools"
  puts "   Google: #{google_good} good competitors"
  puts "   Grounding: #{grounding_good} good competitors"
else
  puts "🤷 TIE - both methods found similar quality competitors"
  puts "   Consider combining both approaches for maximum coverage"
end

puts "="*80
