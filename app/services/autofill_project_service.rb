# app/services/autofill_project_service.rb
# Orchestrates domain analysis and competitor detection to auto-fill project form
class AutofillProjectService
  def initialize(domain, niche: nil)
    @domain = domain
    @niche = niche
  end

  def perform
    Rails.logger.info "Autofilling project data for: #{@domain}"

    # Step 1: Analyze user's domain
    domain_data = analyze_domain

    # Step 2: Detect competitors
    competitors = detect_competitors(domain_data)

    # Step 3: Generate seed keywords from real content
    seeds = generate_seeds(domain_data, competitors)

    {
      description: domain_data[:content_summary],
      seed_keywords: seeds,
      competitors: competitors,
      sitemap_url: domain_data[:sitemap_url],
      domain_analysis: domain_data
    }
  rescue => e
    Rails.logger.error "Autofill failed: #{e.message}"
    {
      error: e.message,
      description: nil,
      seed_keywords: [],
      competitors: [],
      sitemap_url: nil
    }
  end

  private

  def analyze_domain
    service = DomainAnalysisService.new(@domain)
    service.analyze
  end

  def detect_competitors(domain_data)
    Rails.logger.info "Detecting competitors for: #{@domain}"

    begin
      # STEP 1: Use Google Custom Search API to find potential competitor domains
      # Use multiple search queries for broader coverage
      candidate_domains = fetch_competitor_candidates_from_search(domain_data)
      Rails.logger.info "Google Search found #{candidate_domains.size} candidate domains"

      # STEP 2: Scrape each candidate domain to get their actual content
      scraped_candidates = scrape_candidate_domains(candidate_domains)
      Rails.logger.info "Successfully scraped #{scraped_candidates.size} domains"

      # STEP 3: Use Gemini Grounding to analyze scraped content and verify real competitors
      verified_competitors = if scraped_candidates.any?
        verify_with_grounding(scraped_candidates, domain_data)
      else
        []
      end
      Rails.logger.info "Grounding verified #{verified_competitors.size} true competitors from scraped data"

      # STEP 4: Ask Grounding to discover any competitors Google Search may have missed
      additional_competitors = discover_additional_competitors_via_grounding(domain_data, verified_competitors)
      Rails.logger.info "Grounding discovered #{additional_competitors.size} additional competitors"

      # Combine and dedupe
      all_competitors = (verified_competitors + additional_competitors).uniq { |c| c[:domain] }
      Rails.logger.info "Total competitors found: #{all_competitors.size}"

      all_competitors
    rescue => e
      Rails.logger.error "Competitor detection failed: #{e.message}"
      Rails.logger.error e.backtrace.first(3).join("\n")
      []
    end
  end

  def fetch_competitor_candidates_from_search(domain_data)
    title = domain_data[:title] || @domain
    description = domain_data[:meta_description] || ""
    main_terms = extract_key_terms(title, description)

    # Use multiple search query strategies to find actual tool websites
    queries = [
      "#{main_terms} alternatives",
      "#{main_terms} saas tools",
      "#{main_terms} app software",
      "best #{main_terms} platforms"
    ]

    all_candidates = []

    queries.each do |query|
      Rails.logger.info "Searching Google for: #{query}"
      results = fetch_domains_from_google_search(query)
      all_candidates.concat(results)
      sleep 0.5 # Be nice to Google API
    end

    # Dedupe by domain
    all_candidates.uniq { |c| c[:domain] }
  end

  def fetch_domains_from_google_search(query)
    api_key = ENV['GOOGLE_SEARCH_KEY']
    cx = ENV['GOOGLE_SEARCH_CX']

    unless api_key.present?
      Rails.logger.warn "GOOGLE_SEARCH_KEY not configured"
      return []
    end

    require 'net/http'

    all_results = []

    # Fetch 2 pages (20 results) per query to avoid excessive API calls
    [1, 11].each do |start_index|
      uri = URI('https://www.googleapis.com/customsearch/v1')
      params = {
        key: api_key,
        cx: cx,
        q: query,
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

          # Skip own domain and obvious non-competitors
          host = uri_obj.host.gsub(/^www\./, '')
          next if host.include?(@domain.gsub(%r{^https?://}, '').gsub(/^www\./, ''))
          next if is_obvious_non_competitor?(host)

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

    all_results.uniq { |r| r[:domain] }
  rescue => e
    Rails.logger.error "Google Search failed: #{e.message}"
    []
  end

  def is_obvious_non_competitor?(host)
    excluded = [
      'reddit.com', 'medium.com', 'quora.com', 'stackoverflow.com',
      'news.ycombinator.com', 'facebook.com', 'twitter.com', 'linkedin.com',
      'youtube.com', 'techcrunch.com', 'forbes.com', 'wired.com',
      'g2.com', 'capterra.com', 'trustpilot.com', 'producthunt.com',
      'alternativeto.net', 'github.com'
    ]
    excluded.any? { |ex| host.include?(ex) }
  end

  def scrape_candidate_domains(candidates)
    scraped = []

    candidates.first(20).each do |candidate|
      Rails.logger.info "  Scraping #{candidate[:domain]}..."

      scraper = DomainAnalysisService.new(candidate[:domain])
      scraped_data = scraper.analyze

      if scraped_data && !scraped_data[:error]
        scraped << {
          domain: candidate[:domain],
          url: candidate[:url],
          title: scraped_data[:title] || candidate[:title],
          meta_description: scraped_data[:meta_description],
          h1s: scraped_data[:h1s],
          h2s: scraped_data[:h2s],
          content_summary: scraped_data[:content_summary]
        }
      end

      sleep 1 # Be nice
    end

    scraped
  end

  def verify_with_grounding(scraped_candidates, domain_data)
    grounding = GoogleGroundingService.new

    my_title = domain_data[:title] || @domain
    my_description = domain_data[:meta_description] || ""

    # Build detailed list of scraped competitors
    candidate_list = scraped_candidates.map do |c|
      <<~CANDIDATE
        Domain: #{c[:domain]}
        Title: #{c[:title]}
        Description: #{c[:meta_description]}
        Main Topics: #{c[:h1s]&.first(2)&.join(', ')}
        ---
      CANDIDATE
    end.join("\n")

    query = <<~QUERY
      I scraped potential competitor websites. Your job: determine which are TRUE direct competitors.

      MY BUSINESS:
      Title: #{my_title}
      Description: #{my_description}
      Website: #{@domain}

      SCRAPED CANDIDATES:
      #{candidate_list}

      FILTERING CRITERIA - Must pass ALL tests:
      1. Same primary job - customers would use THIS instead of my business for the SAME task?
      2. Same product category - not adjacent/related categories
      3. Dedicated tool - not general platforms
      4. Actual software - not blogs/news/content sites

      For each TRUE competitor:
      - Verify by researching the domain if needed
      - Return domain (without https://), title, and what they do

      Return ONLY valid JSON array of verified competitors:
      [
        {
          "domain": "competitor.com",
          "title": "Company Name",
          "description": "What they actually do"
        }
      ]

      Be strict - only include clear matches that pass all 4 tests.
    QUERY

    json_structure = [{domain: "competitor.com", title: "Name", description: "What they do"}].to_json
    result = grounding.search_json(query, json_structure_hint: json_structure)

    return [] unless result[:success]

    Rails.logger.info "Grounding sources: #{result[:grounding_metadata][:sources_count]}"
    parse_competitor_data(result[:data])
  end

  def discover_additional_competitors_via_grounding(domain_data, already_found)
    grounding = GoogleGroundingService.new

    my_title = domain_data[:title] || @domain
    my_description = domain_data[:meta_description] || ""

    # Build list of already found competitors to avoid duplicates
    already_found_list = if already_found.any?
      already_found.map { |c| "- #{c[:domain]}" }.join("\n")
    else
      "(none found yet)"
    end

    query = <<~QUERY
      Search the web to find direct competitor tools for this business.

      MY BUSINESS:
      Title: #{my_title}
      Description: #{my_description}
      Website: #{@domain}

      ALREADY FOUND (do NOT include these):
      #{already_found_list}

      Your job: Find OTHER direct competitors we may have missed.

      FILTERING CRITERIA - Must pass ALL tests:
      1. Same primary job - customers would use THIS instead of my business for the SAME task?
      2. Same product category - not adjacent/related categories
      3. Dedicated tool - not general platforms
      4. Actual software - not blogs/news/content sites

      For each competitor you find:
      - Research the domain to verify it's a real competitor
      - Return domain (without https://), title, and what they do

      Return ONLY valid JSON array (find 3-10 additional competitors if they exist):
      [
        {
          "domain": "competitor.com",
          "title": "Company Name",
          "description": "What they actually do"
        }
      ]

      Be strict - only include clear matches that pass all 4 tests.
    QUERY

    json_structure = [{domain: "competitor.com", title: "Name", description: "What they do"}].to_json
    result = grounding.search_json(query, json_structure_hint: json_structure)

    return [] unless result[:success]

    Rails.logger.info "Additional discovery sources: #{result[:grounding_metadata][:sources_count]}"
    parse_competitor_data(result[:data])
  end

  def extract_key_terms(title, description)
    # Remove common words and extract main concept
    combined = "#{title} #{description}".downcase

    # Remove common words
    stop_words = %w[the a an and or but for with from about in on at to of is are was were be been being have has had do does did will would could should may might must can]
    words = combined.split(/\W+/).reject { |w| stop_words.include?(w) || w.length < 3 }

    # Take first 3-5 meaningful words
    words.first(4).join(' ')
  end

  def parse_competitor_data(data)
    competitors_array = case data
    when Array
      data
    when Hash
      data["competitors"] || []
    else
      []
    end

    competitors_array.map do |c|
      domain = normalize_competitor_domain(c)
      next unless domain

      {
        domain: domain,
        title: c["title"] || c["name"] || extract_site_name(domain),
        description: c["description"] || c["what_they_do"] || "",
        source: 'auto_detected'
      }
    end.compact
  end

  def normalize_competitor_domain(competitor)
    domain = competitor.is_a?(Hash) ? (competitor["domain"] || competitor["url"]) : competitor
    return nil if domain.blank?

    # Clean up domain
    domain = domain.to_s.strip
                 .gsub(%r{^https?://}, '')
                 .gsub(%r{^www\.}, '')
                 .gsub(%r{/$}, '')
                 .split('/').first
                 .downcase

    return nil if domain.empty? || !domain.include?('.')

    # Add https:// prefix for consistency
    "https://#{domain}"
  end

  def extract_site_name(domain)
    # Extract name from domain (e.g., "bizway" from "https://bizway.io")
    uri = URI.parse(domain)
    host = uri.host.gsub(/^www\./, '')
    host.split('.').first.capitalize
  rescue
    "Competitor"
  end


  def generate_seeds(domain_data, competitors)
    # Use SeedKeywordGenerator in raw domain mode (no project yet)
    competitor_domains = competitors.map { |c| c[:domain] }

    generator = SeedKeywordGenerator.new(
      @domain,
      niche: @niche,
      competitors: competitor_domains
    )

    # Use the new method that accepts competitor domains directly
    generator.generate_with_competitors(competitor_domains)
  end
end
