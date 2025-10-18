#!/usr/bin/env ruby
# scripts/compare_competitor_discovery.rb
# Compare Google Search vs Grounding for competitor discovery

require_relative '../config/environment'

domain = "https://validatorai.com"

puts "\n" + "="*80
puts "COMPETITOR DISCOVERY COMPARISON TEST"
puts "Domain: #{domain}"
puts "="*80

# Get domain data
puts "\nAnalyzing domain..."
analyzer = DomainAnalysisService.new(domain)
domain_data = analyzer.analyze

puts "  Title: #{domain_data[:title]}"
puts "  Description: #{domain_data[:meta_description]}"

# METHOD 1: Google Search (raw, no hardcoded patterns)
puts "\n" + "-"*80
puts "METHOD 1: Google Custom Search API (raw search)"
puts "-"*80

title = domain_data[:title] || domain
description = domain_data[:meta_description] || ""

# Extract key terms
combined = "#{title} #{description}".downcase
stop_words = %w[the a an and or but for with from about in on at to of is are was were be been being have has had do does did will would could should may might must can]
words = combined.split(/\W+/).reject { |w| stop_words.include?(w) || w.length < 3 }
main_terms = words.first(4).join(' ')

puts "Search query: '#{main_terms}'"

api_key = ENV['GOOGLE_SEARCH_KEY']
cx = ENV['GOOGLE_SEARCH_CX']

google_competitors = []

if api_key.present?
  require 'net/http'

  all_results = []

  [1, 11, 21].each do |start_index|
    uri = URI('https://www.googleapis.com/customsearch/v1')
    params = {
      key: api_key,
      cx: cx,
      q: main_terms,
      start: start_index,
      num: 10
    }
    uri.query = URI.encode_www_form(params)

    response = Net::HTTP.get_response(uri)
    next unless response.is_a?(Net::HTTPSuccess)

    data = JSON.parse(response.body)
    items = data['items'] || []

    items.each do |item|
      next unless item['link']

      begin
        url = item['link']
        uri_obj = URI(url)
        host = uri_obj.host.gsub(/^www\./, '')

        next if host.include?(domain.gsub(%r{^https?://}, '').gsub(/^www\./, ''))

        all_results << {
          url: url,
          domain: "https://#{uri_obj.host}",
          title: item['title'],
          snippet: item['snippet']
        }
      rescue URI::InvalidURIError
        next
      end
    end

    sleep 0.3
  end

  google_competitors = all_results.uniq { |r| r[:domain] }.map do |r|
    {
      domain: r[:domain].gsub(%r{^https?://}, '').gsub(/^www\./, ''),
      title: r[:title],
      description: r[:snippet]
    }
  end

  puts "\nGoogle Search Results: #{google_competitors.size} competitors"
  google_competitors.first(20).each_with_index do |comp, i|
    puts "  #{i+1}. #{comp[:domain]}"
    puts "     #{comp[:title]}"
  end
else
  puts "\nGoogle Search API not configured"
end

# METHOD 2: Pure Grounding
puts "\n" + "-"*80
puts "METHOD 2: Pure Google Grounding"
puts "-"*80

grounding = GoogleGroundingService.new

query = <<~QUERY
  Search the web to find direct competitor tools for this business.

  MY BUSINESS:
  Title: #{title}
  Description: #{description}
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

# Summary
puts "\n" + "="*80
puts "SUMMARY"
puts "="*80
puts "Google Search found: #{google_competitors.size} competitors"
puts "Grounding found: #{grounding_competitors.size} competitors"
puts ""

google_domains = google_competitors.map{|c| c[:domain]}
grounding_domains = grounding_competitors.map{|c| c[:domain]}

overlap = (google_domains & grounding_domains)
puts "Overlap: #{overlap.size} competitors"
overlap.each { |d| puts "  - #{d}" }
puts ""

google_only = google_domains - grounding_domains
puts "Google-only competitors (#{google_only.size}):"
google_only.first(10).each { |d| puts "  - #{d}" }
puts ""

grounding_only = grounding_domains - google_domains
puts "Grounding-only competitors (#{grounding_only.size}):"
grounding_only.each { |d| puts "  - #{d}" }
puts "="*80
