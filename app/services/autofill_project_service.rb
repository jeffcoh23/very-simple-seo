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
      # Use pure Grounding - it's better at finding actual competitors than Google Search
      # (Google Search returns mostly review sites, blog posts, and listings)
      grounding = GoogleGroundingService.new

      my_title = domain_data[:title] || @domain
      my_description = domain_data[:meta_description] || ""

      query = <<~QUERY
        Search the web to find direct competitor tools for this business.

        MY BUSINESS:
        Title: #{my_title}
        Description: #{my_description}
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

      json_structure = [{domain: "competitor.com", title: "Name", description: "What they do"}].to_json
      result = grounding.search_json(query, json_structure_hint: json_structure)

      return [] unless result[:success]

      Rails.logger.info "Grounding sources: #{result[:grounding_metadata][:sources_count]}"

      competitors = parse_competitor_data(result[:data])
      Rails.logger.info "Found #{competitors.size} competitors"

      competitors
    rescue => e
      Rails.logger.error "Competitor detection failed: #{e.message}"
      Rails.logger.error e.backtrace.first(3).join("\n")
      []
    end
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
