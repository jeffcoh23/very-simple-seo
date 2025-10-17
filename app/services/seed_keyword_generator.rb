# app/services/seed_keyword_generator.rb
# Generates seed keywords using Google Grounding (FREE) based on ACTUAL domain content + competitor analysis
class SeedKeywordGenerator
  def initialize(project_or_domain, niche: nil, competitors: [])
    # Support both Project object and raw domain data
    if project_or_domain.is_a?(String)
      # Raw domain mode (for autofill before project exists)
      @project = nil
      @domain = project_or_domain
      @niche = niche
      @competitors = competitors
    else
      # Project mode (normal usage)
      @project = project_or_domain
      @domain = @project.domain
      @niche = @project.niche
      @competitors = @project.competitors.pluck(:domain)
    end

    @grounding = GoogleGroundingService.new
    @api_calls_used = 0
  end

  # New method: accepts competitor DOMAINS (not scraped data)
  # Grounding will research them directly
  def generate_with_competitors(competitor_domains)
    Rails.logger.info "Generating seed keywords with Grounding for: #{@domain}"
    Rails.logger.info "Using #{competitor_domains.size} competitor domains for context"

    # Generate seeds via Grounding (it will analyze domain + competitors)
    seeds = generate_seeds_via_grounding(competitor_domains)
    @api_calls_used += 1
    Rails.logger.info "  Generated #{seeds.size} seeds from Grounding (API calls: #{@api_calls_used})"

    Rails.logger.info "Total API calls used: #{@api_calls_used}"
    seeds
  end

  # DEPRECATED: Old scraping-based method - use generate_with_competitors instead
  # def generate
  #   Rails.logger.info "Generating seed keywords with Grounding for: #{@domain}"
  #   Rails.logger.info "API call budget: 3 Grounding calls max"
  #
  #   # Step 1: Scrape YOUR domain
  #   domain_data = @project&.domain_analysis || scrape_domain
  #
  #   # Step 2: Discover competitors via Grounding (if none manually added)
  #   competitor_domains = discover_competitors_via_grounding
  #   @api_calls_used += 1
  #   Rails.logger.info "  Discovered #{competitor_domains.size} competitors (API calls: #{@api_calls_used})"
  #
  #   # Step 3: Scrape competitors
  #   competitor_data = scrape_competitors(competitor_domains)
  #   Rails.logger.info "  Scraped #{competitor_data.size} competitors"
  #
  #   # Step 4: Generate seed keywords via Grounding based on YOUR domain + competitor data
  #   seeds = generate_seeds_via_grounding(domain_data, competitor_data)
  #   @api_calls_used += 1
  #   Rails.logger.info "  Generated #{seeds.size} seeds from Grounding (API calls: #{@api_calls_used})"
  #
  #   Rails.logger.info "Total API calls used: #{@api_calls_used}"
  #   seeds
  # end

  private

  # DEPRECATED: Old scraping methods - no longer needed with Grounding
  # def scrape_domain
  #   Rails.logger.info "Scraping YOUR domain for content analysis..."
  #   service = DomainAnalysisService.new(@domain)
  #   domain_data = service.analyze
  #
  #   # Store it on project for future use (if we have a project)
  #   @project&.update(domain_analysis: domain_data) if domain_data && !domain_data[:error]
  #
  #   domain_data
  # end
  #
  # def discover_competitors_via_grounding
  #   # If user manually added competitors, use those
  #   return @competitors if @competitors.any?
  #
  #   query = "Find the top 10 direct competitor domains for #{@domain} in the #{@niche} space"
  #
  #   json_structure = [
  #     "competitor1.com",
  #     "competitor2.com",
  #     "competitor3.com"
  #   ].to_json
  #
  #   result = @grounding.search_json(query, json_structure_hint: json_structure)
  #
  #   unless result[:success]
  #     Rails.logger.warn "Competitor discovery failed: #{result[:error]}"
  #     return []
  #   end
  #
  #   # Parse competitor domains from JSON response
  #   competitors = result[:data]
  #
  #   # Handle different response formats
  #   competitors = case competitors
  #   when Array
  #     competitors.map { |c| normalize_competitor(c) }
  #   when Hash
  #     (competitors["competitors"] || competitors["domains"] || []).map { |c| normalize_competitor(c) }
  #   else
  #     []
  #   end
  #
  #   competitors.compact.uniq.first(10)
  # rescue => e
  #   Rails.logger.error "Competitor discovery error: #{e.message}"
  #   []
  # end
  #
  # def scrape_competitors(competitor_domains)
  #   return [] if competitor_domains.empty?
  #
  #   Rails.logger.info "Scraping #{competitor_domains.size} competitors..."
  #
  #   competitor_data = []
  #
  #   competitor_domains.first(10).each do |competitor_domain|
  #     Rails.logger.info "  Scraping #{competitor_domain}..."
  #     service = DomainAnalysisService.new(competitor_domain)
  #     data = service.analyze
  #
  #     if data && !data[:error]
  #       competitor_data << data
  #     end
  #
  #     sleep 1 # Be nice to servers
  #   end
  #
  #   competitor_data
  # end

  # Generate seeds via Grounding - let it research the domain + competitors
  def generate_seeds_via_grounding(competitor_domains)
    # Clean the description (same fix as competitor discovery)
    raw_description = if @project
      @project.description.presence || "#{@project.name} - #{@niche}"
    else
      @niche || "Unknown business"
    end

    description = if raw_description.include?("Description:")
      raw_description.split("Description:").last.strip
    else
      raw_description
    end

    # Build competitor list for Grounding to research
    competitor_list = if competitor_domains.any?
      competitor_domains.first(10).map { |d| "- https://#{d}" }.join("\n")
    else
      "(No competitors provided - analyze the main domain only)"
    end

    query = <<~QUERY
      Analyze this business and generate 25 high-quality SEO seed keywords.

      BUSINESS TO ANALYZE:
      #{description}
      Website: #{@domain}

      TOP COMPETITORS (for context):
      #{competitor_list}

      IMPORTANT: Visit the website and analyze what they ACTUALLY offer.
      Do NOT generate keywords based only on the domain name.

      Generate 25 seed keywords that:
      - Match what the business ACTUALLY does (not just the domain name)
      - Have clear search intent (what users would actually search for)
      - Mix broad and specific terms naturally (YOU decide the best mix)
      - Focus on the core value proposition and target audience

      Return ONLY a JSON array of keyword strings (no objects, just strings):
      ["keyword 1", "keyword 2", "keyword 3"]

      No markdown code blocks, just pure JSON.
    QUERY

    json_structure = ["keyword 1", "keyword 2", "keyword 3"].to_json

    result = @grounding.search_json(query, json_structure_hint: json_structure)

    unless result[:success]
      Rails.logger.warn "Seed generation failed: #{result[:error]}, using fallback"
      return fallback_seeds(description)
    end

    # Parse keywords from JSON response
    keywords = result[:data]

    # Handle different response formats
    keywords = case keywords
    when Array
      keywords.map { |k| clean_keyword(k) }
    when Hash
      (keywords["keywords"] || keywords["seeds"] || []).map { |k| clean_keyword(k) }
    else
      []
    end

    keywords.compact.uniq.first(25)
  rescue => e
    Rails.logger.error "Seed generation error: #{e.message}, using fallback"
    fallback_seeds(description)
  end

  # Fallback to OpenAI if Grounding fails
  def fallback_to_openai(domain_data, competitor_data)
    Rails.logger.info "Using OpenAI fallback for seed generation"

    client = Ai::ClientService.for_keyword_analysis
    prompt = build_openai_prompt(domain_data, competitor_data)

    response = client.chat(
      messages: [{ role: "user", content: prompt }],
      system_prompt: "You are an expert SEO strategist who generates keyword ideas based on actual website content.",
      max_tokens: 2000,
      temperature: 0.7
    )

    if response[:success]
      parse_keywords(response[:content])
    else
      Rails.logger.error "OpenAI fallback also failed: #{response[:error]}"
      fallback_seeds(domain_data)
    end
  end

  def build_openai_prompt(domain_data, competitor_data)
    title = domain_data[:title] || "Unknown"
    meta_desc = domain_data[:meta_description] || "Not available"
    h1s = domain_data[:h1s]&.join(", ") || "Not available"
    h2s = domain_data[:h2s]&.first(5)&.join(", ") || "Not available"

    competitor_insights = ""
    if competitor_data.any?
      competitor_insights = "\nCOMPETITOR ANALYSIS:\n"
      competitor_data.each_with_index do |comp_data, index|
        comp_title = comp_data[:title] || "Unknown"
        comp_h1s = comp_data[:h1s]&.first(3)&.join(", ") || "Not available"
        competitor_insights += "Competitor #{index + 1}: #{comp_title}\nKey Topics: #{comp_h1s}\n\n"
      end
    end

    <<~PROMPT
      I need seed keywords for an SEO content strategy.

      DOMAIN ANALYSIS (based on actual website content):
      Domain: #{@domain}
      Page Title: #{title}
      Meta Description: #{meta_desc}
      Main Headings (H1s): #{h1s}
      Content Topics (H2s): #{h2s}
      #{@niche.present? ? "Niche: #{@niche}" : ""}
      #{competitor_insights}

      Based on the ACTUAL content from this website (not just the domain name), generate 20-30 seed keywords with STRATEGIC DIVERSITY:

      HIGH-VOLUME BROAD (5-8 keywords, 1-2 words) - The "money" keywords, even if competitive
      MEDIUM-COMPETITION (6-9 keywords, 2-4 words) - Realistic wins within 6-12 months
      LOW-COMPETITION LONG-TAIL (6-9 keywords, 4-6 words) - Quick wins, very specific

      Return ONLY the keywords, one per line, without numbering or extra explanation.
      Focus on keywords with commercial or informational intent.
    PROMPT
  end

  def normalize_competitor(competitor)
    return nil if competitor.blank?

    domain = competitor.is_a?(Hash) ? (competitor["domain"] || competitor["url"]) : competitor
    return nil if domain.blank?

    domain = domain.to_s.strip
                   .gsub(%r{^https?://}, '')
                   .gsub(%r{^www\.}, '')
                   .gsub(%r{/$}, '')
                   .split('/').first

    return nil if domain.empty? || !domain.include?('.')

    domain.downcase
  end

  def clean_keyword(keyword)
    return nil if keyword.blank?

    kw = keyword.is_a?(Hash) ? (keyword["keyword"] || keyword["text"]) : keyword
    return nil if kw.blank?

    kw = kw.to_s.strip
           .gsub(/^["'\(\)]/, '')
           .gsub(/["'\(\)]$/, '')
           .gsub(/\s+/, ' ')
           .downcase

    return nil unless valid_keyword?(kw)

    kw
  end

  def valid_keyword?(keyword)
    return false if keyword.blank?
    return false if keyword.length < 2 || keyword.length > 100 # Allow 2-letter keywords like "ai", "ux"
    return false if keyword.split.size > 8
    return false if keyword.match?(/^\d+$/)

    true
  end

  def parse_keywords(content)
    keywords = content.split("\n")
                     .map { |line| line.strip }
                     .map { |line| line.gsub(/^\d+[\.\)]\s*/, '') }
                     .map { |line| line.gsub(/^[-*•]\s*/, '') }
                     .select { |line| line.length > 0 && line.length < 100 }
                     .map(&:downcase)

    keywords.uniq
  end

  def fallback_seeds(description)
    Rails.logger.warn "Using fallback: generating basic seeds from description"

    # Extract key terms from description
    words = description.downcase.split(/\W+/)
    common_words = %w[the a an and or but for with from about in on at to of is are was were be been being have has had do does did will would could should may might must can]
    key_terms = words.reject { |w| common_words.include?(w) || w.length < 3 }.uniq

    # Generate basic seed variations
    seeds = []
    key_terms.first(5).each do |term|
      seeds << term
      seeds << "#{term} tool"
      seeds << "best #{term}"
      seeds << "how to #{term}"
      seeds << "#{term} software"
    end

    # Add niche-specific seeds if available
    if @niche.present?
      seeds << @niche
      seeds << "#{@niche} guide"
      seeds << "best #{@niche}"
    end

    seeds.compact.uniq.first(20)
  end
end
