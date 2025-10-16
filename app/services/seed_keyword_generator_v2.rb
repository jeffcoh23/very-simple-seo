# app/services/seed_keyword_generator_v2.rb
# Efficient seed generation: max 2-3 Google Grounding API calls
# Process: Discover competitors (1 call) → Scrape → Generate seeds (1 call) → Optional trends (1 call)

class SeedKeywordGeneratorV2
  def initialize(project_or_domain, niche: nil, competitors: [])
    # Support both Project object and raw domain data
    if project_or_domain.is_a?(String)
      @project = nil
      @domain = project_or_domain
      @niche = niche
      @competitors = competitors
    else
      @project = project_or_domain
      @domain = @project.domain
      @niche = @project.niche
      @competitors = @project.competitors.pluck(:domain)
    end

    @grounding = GoogleGroundingService.new
    @api_calls_used = 0
  end

  def generate
    Rails.logger.info "Generating V2 seeds with Grounding for: #{@domain}"
    Rails.logger.info "API call budget: 3 calls max"

    all_seeds = []

    # Step 1: Discover competitors via Grounding (1 API call)
    competitor_domains = discover_competitors_json
    @api_calls_used += 1
    Rails.logger.info "  Discovered #{competitor_domains.size} competitors (API calls: #{@api_calls_used})"

    # Step 2: Scrape competitors (no API calls - using existing scraper)
    scraped_content = scrape_competitors(competitor_domains)
    Rails.logger.info "  Scraped #{scraped_content.size} competitors"

    # Step 3: Generate seed keywords from niche + scraped content (1 API call)
    seed_keywords = generate_seeds_json(scraped_content)
    @api_calls_used += 1
    all_seeds.concat(seed_keywords)
    Rails.logger.info "  Generated #{seed_keywords.size} seeds from competitors (API calls: #{@api_calls_used})"

    # Step 4: Optional - Get trending keywords (1 API call)
    if @api_calls_used < 3 && @niche.present?
      trending = get_trending_keywords_json
      @api_calls_used += 1
      all_seeds.concat(trending)
      Rails.logger.info "  Added #{trending.size} trending seeds (API calls: #{@api_calls_used})"
    end

    # Clean and dedupe
    final_seeds = all_seeds.map(&:downcase)
                           .map(&:strip)
                           .uniq
                           .select { |s| valid_seed?(s) }
                           .first(50)

    Rails.logger.info "Generated #{final_seeds.size} total V2 seeds using #{@api_calls_used} API calls"
    final_seeds
  end

  private

  # Step 1: Discover competitors using single JSON API call
  def discover_competitors_json
    return @competitors if @competitors.any?

    query = "Find top 10 competitor domains for #{@domain} in the #{@niche} space"

    json_structure = [
      "competitor1.com",
      "competitor2.com",
      "competitor3.com"
    ].to_json

    result = @grounding.search_json(query, json_structure_hint: json_structure)

    unless result[:success]
      Rails.logger.warn "Competitor discovery failed: #{result[:error]}"
      return []
    end

    # Parse competitor domains from JSON response
    competitors = result[:data]

    # Handle different response formats
    competitors = case competitors
    when Array
      competitors.map { |c| normalize_competitor(c) }
    when Hash
      # If response is {"competitors": [...]}
      (competitors["competitors"] || competitors["domains"] || []).map { |c| normalize_competitor(c) }
    else
      []
    end

    competitors.compact.uniq.first(10)
  rescue => e
    Rails.logger.error "Competitor discovery error: #{e.message}"
    []
  end

  # Step 2: Scrape competitors using existing DomainScraperService (no API calls)
  def scrape_competitors(competitor_domains)
    return {} if competitor_domains.empty?

    scraped_data = {}

    competitor_domains.first(5).each do |domain|
      begin
        scraper = DomainScraperService.new(domain)
        content = scraper.scrape

        if content[:success]
          scraped_data[domain] = {
            title: content[:title],
            description: content[:description],
            content: content[:content]&.first(1000) # Limit to 1000 chars
          }
        end
      rescue => e
        Rails.logger.warn "Failed to scrape #{domain}: #{e.message}"
      end
    end

    scraped_data
  end

  # Step 3: Generate seed keywords from niche + competitor content (1 API call)
  def generate_seeds_json(scraped_content)
    # Build context from scraped competitor data
    competitor_context = scraped_content.map do |domain, data|
      "#{domain}: #{data[:title]} - #{data[:description]}"
    end.join("\n")

    query = <<~QUERY
      Based on this #{@niche} business (#{@domain}) and these competitors:

      #{competitor_context}

      Generate 40 high-value SEO seed keywords that this #{@niche} business should target.
      Include:
      - Core product/service keywords
      - Problem-solution keywords
      - Comparison keywords
      - Long-tail variations
    QUERY

    json_structure = [
      "keyword 1",
      "keyword 2",
      "keyword 3"
    ].to_json

    result = @grounding.search_json(query, json_structure_hint: json_structure)

    unless result[:success]
      Rails.logger.warn "Seed generation failed: #{result[:error]}"
      return []
    end

    # Parse keywords from JSON response
    keywords = result[:data]

    # Handle different response formats
    keywords = case keywords
    when Array
      keywords.map { |k| clean_keyword(k) }
    when Hash
      # If response is {"keywords": [...]}
      (keywords["keywords"] || keywords["seeds"] || []).map { |k| clean_keyword(k) }
    else
      []
    end

    keywords.compact.uniq
  rescue => e
    Rails.logger.error "Seed generation error: #{e.message}"
    []
  end

  # Step 4: Get trending keywords (optional, 1 API call)
  def get_trending_keywords_json
    return [] unless @niche.present?

    query = "What are the top 15 trending search keywords in the #{@niche} industry in 2025?"

    json_structure = [
      "trending keyword 1",
      "trending keyword 2",
      "trending keyword 3"
    ].to_json

    result = @grounding.search_json(query, json_structure_hint: json_structure)

    unless result[:success]
      Rails.logger.warn "Trending keywords failed: #{result[:error]}"
      return []
    end

    keywords = result[:data]

    # Handle different response formats
    keywords = case keywords
    when Array
      keywords.map { |k| clean_keyword(k) }
    when Hash
      (keywords["keywords"] || keywords["trending"] || []).map { |k| clean_keyword(k) }
    else
      []
    end

    keywords.compact.uniq
  rescue => e
    Rails.logger.error "Trending keywords error: #{e.message}"
    []
  end

  # Normalize competitor domain format
  def normalize_competitor(competitor)
    return nil if competitor.blank?

    # Handle if competitor is a hash with domain field
    domain = competitor.is_a?(Hash) ? (competitor["domain"] || competitor["url"]) : competitor

    return nil if domain.blank?

    # Clean up domain
    domain = domain.to_s.strip
                   .gsub(%r{^https?://}, '')
                   .gsub(%r{^www\.}, '')
                   .gsub(%r{/$}, '')
                   .split('/').first # Remove path

    return nil if domain.empty? || !domain.include?('.')

    domain.downcase
  end

  # Clean and validate keyword
  def clean_keyword(keyword)
    return nil if keyword.blank?

    # Handle if keyword is a hash with text field
    kw = keyword.is_a?(Hash) ? (keyword["keyword"] || keyword["text"]) : keyword

    return nil if kw.blank?

    kw = kw.to_s.strip
           .gsub(/^["'\(\)]/, '')
           .gsub(/["'\(\)]$/, '')
           .gsub(/\s+/, ' ')
           .downcase

    return nil unless valid_seed?(kw)

    kw
  end

  # Validate seed keyword
  def valid_seed?(keyword)
    return false if keyword.blank?
    return false if keyword.length < 3 || keyword.length > 100
    return false if keyword.split.size > 8 # No super long phrases
    return false if keyword.match?(/^\d+$/) # No pure numbers
    return false if keyword.match?(/[^\w\s\-']/) # Only alphanumeric, spaces, hyphens, apostrophes

    true
  end
end
