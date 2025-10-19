# test/services/competitor_discovery_comparison_test.rb
# Run this to compare Google Search vs Grounding for competitor discovery
require "test_helper"

class CompetitorDiscoveryComparisonTest < ActiveSupport::TestCase
  def setup
    @domain = "https://validatorai.com"
    @niche = nil
  end

  test "compare google search vs grounding for competitor discovery" do
    puts "\n" + "="*80
    puts "COMPETITOR DISCOVERY COMPARISON TEST"
    puts "Domain: #{@domain}"
    puts "="*80

    # Get domain data first
    analyzer = DomainAnalysisService.new(@domain)
    domain_data = analyzer.analyze

    puts "\nDomain Analysis:"
    puts "  Title: #{domain_data[:title]}"
    puts "  Description: #{domain_data[:meta_description]}"
    puts ""

    # METHOD 1: Google Custom Search API (raw results, minimal filtering)
    puts "\n" + "-"*80
    puts "METHOD 1: Google Custom Search API"
    puts "-"*80

    google_competitors = test_google_search_method(domain_data)

    puts "\nGoogle Search Results: #{google_competitors.size} competitors"
    google_competitors.each_with_index do |comp, i|
      puts "  #{i+1}. #{comp[:domain]}"
      puts "     #{comp[:title]}"
    end

    # METHOD 2: Pure Grounding (let it search and filter)
    puts "\n" + "-"*80
    puts "METHOD 2: Pure Google Grounding"
    puts "-"*80

    grounding_competitors = test_grounding_method(domain_data)

    puts "\nGrounding Results: #{grounding_competitors.size} competitors"
    grounding_competitors.each_with_index do |comp, i|
      puts "  #{i+1}. #{comp[:domain]}"
      puts "     #{comp[:title]}"
      puts "     #{comp[:description]}"
    end

    # Summary
    puts "\n" + "="*80
    puts "SUMMARY"
    puts "="*80
    puts "Google Search found: #{google_competitors.size} competitors"
    puts "Grounding found: #{grounding_competitors.size} competitors"
    puts ""
    puts "Overlap: #{(google_competitors.map { |c| c[:domain] } & grounding_competitors.map { |c| c[:domain] }).size} competitors"
    puts ""
    puts "Google-only competitors:"
    (google_competitors.map { |c| c[:domain] } - grounding_competitors.map { |c| c[:domain] }).each do |domain|
      puts "  - #{domain}"
    end
    puts ""
    puts "Grounding-only competitors:"
    (grounding_competitors.map { |c| c[:domain] } - google_competitors.map { |c| c[:domain] }).each do |domain|
      puts "  - #{domain}"
    end
    puts "="*80
  end

  private

  def test_google_search_method(domain_data)
    # Simple Google Search: just search for the main terms without hardcoded patterns
    title = domain_data[:title] || @domain
    description = domain_data[:meta_description] || ""

    # Extract key terms
    combined = "#{title} #{description}".downcase
    stop_words = %w[the a an and or but for with from about in on at to of is are was were be been being have has had do does did will would could should may might must can]
    words = combined.split(/\W+/).reject { |w| stop_words.include?(w) || w.length < 3 }
    main_terms = words.first(4).join(" ")

    puts "Search query: '#{main_terms}'"

    api_key = ENV["GOOGLE_SEARCH_KEY"]
    cx = ENV["GOOGLE_SEARCH_CX"]

    return [] unless api_key.present?

    require "net/http"

    all_results = []

    # Fetch 3 pages (30 results)
    [ 1, 11, 21 ].each do |start_index|
      uri = URI("https://www.googleapis.com/customsearch/v1")
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
      items = data["items"] || []

      items.each do |item|
        next unless item["link"]

        begin
          url = item["link"]
          uri_obj = URI(url)
          host = uri_obj.host.gsub(/^www\./, "")

          # Skip own domain only
          next if host.include?(@domain.gsub(%r{^https?://}, "").gsub(/^www\./, ""))

          all_results << {
            url: url,
            domain: "https://#{uri_obj.host}",
            title: item["title"],
            snippet: item["snippet"]
          }
        rescue URI::InvalidURIError
          next
        end
      end

      sleep 0.3
    end

    all_results.uniq { |r| r[:domain] }.map do |r|
      {
        domain: r[:domain].gsub(%r{^https?://}, "").gsub(/^www\./, ""),
        title: r[:title],
        description: r[:snippet]
      }
    end
  rescue => e
    Rails.logger.error "Google Search test failed: #{e.message}"
    []
  end

  def test_grounding_method(domain_data)
    grounding = GoogleGroundingService.new

    title = domain_data[:title] || @domain
    description = domain_data[:meta_description] || ""

    query = <<~QUERY
      Search the web to find direct competitor tools for this business.

      MY BUSINESS:
      Title: #{title}
      Description: #{description}
      Website: #{@domain}

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

    json_structure = [ { domain: "competitor.com", title: "Name", description: "What they do" } ].to_json
    result = grounding.search_json(query, json_structure_hint: json_structure)

    return [] unless result[:success]

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

    competitors_array.map do |c|
      domain = c["domain"] || c["url"]
      next unless domain

      domain = domain.to_s.strip
                   .gsub(%r{^https?://}, "")
                   .gsub(%r{^www\.}, "")
                   .gsub(%r{/$}, "")
                   .split("/").first
                   .downcase

      next if domain.empty? || !domain.include?(".")

      {
        domain: domain,
        title: c["title"] || c["name"] || domain.split(".").first.capitalize,
        description: c["description"] || c["what_they_do"] || ""
      }
    end.compact
  rescue => e
    Rails.logger.error "Grounding test failed: #{e.message}"
    []
  end
end
