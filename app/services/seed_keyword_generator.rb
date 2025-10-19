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

  # Generate seeds with OpenAI using YOUR domain + competitor data
  def generate(competitor_data = [])
    Rails.logger.info "Generating seed keywords for: #{@domain}"
    Rails.logger.info "Using #{competitor_data.size} competitor data for context"

    # Get domain data from project or scrape now
    domain_data = @project&.domain_analysis || scrape_domain

    # Generate seeds via OpenAI with strategic mix prompt
    seeds = generate_seeds_via_openai(domain_data, competitor_data)
    Rails.logger.info "  Generated #{seeds.size} seeds from OpenAI"

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

  def scrape_domain
    Rails.logger.info "Scraping domain for content analysis..."
    service = DomainAnalysisService.new(@domain)
    domain_data = service.analyze

    # Store it on project for future use (if we have a project)
    @project&.update(domain_analysis: domain_data) if domain_data && !domain_data[:error]

    domain_data
  end

  # Generate seeds via OpenAI with strategic mix and competitor insights
  def generate_seeds_via_openai(domain_data, competitor_data)
    client = Ai::ClientService.for_keyword_analysis

    # Build competitor insights from scraped data
    competitor_insights = ""
    if competitor_data.any?
      competitor_insights = "\nCOMPETITOR ANALYSIS:\n"
      competitor_data.first(5).each_with_index do |comp_data, index|
        comp_title = comp_data[:title] || "Unknown"
        comp_h1s = comp_data[:h1s]&.first(3)&.join(", ") || "Not available"
        comp_h2s = comp_data[:h2s]&.first(3)&.join(", ") || "Not available"
        competitor_insights += "Competitor #{index + 1}: #{comp_title}\n"
        competitor_insights += "  Main topics: #{comp_h1s}\n"
        competitor_insights += "  Content areas: #{comp_h2s}\n\n"
      end
    end

    title = domain_data[:title] || "Unknown"
    meta_desc = domain_data[:meta_description] || "Not available"
    h1s = domain_data[:h1s]&.join(", ") || "Not available"
    h2s = domain_data[:h2s]&.first(5)&.join(", ") || "Not available"

    prompt = <<~PROMPT
      I need seed keywords for an SEO content strategy.

      DOMAIN ANALYSIS (based on actual website content):
      Domain: #{@domain}
      Page Title: #{title}
      Meta Description: #{meta_desc}
      Main Headings (H1s): #{h1s}
      Content Topics (H2s): #{h2s}
      #{@niche.present? ? "Niche: #{@niche}" : ""}
      #{competitor_insights}

      Based on the ACTUAL content from this website (not just the domain name), generate 20 seed keywords with STRATEGIC DIVERSITY:

      ═══════════════════════════════════════════════════════════════
      TIER 1: HIGH-VOLUME BROAD (8 keywords, 1-3 words)
      ═══════════════════════════════════════════════════════════════
      The "money keywords" - high search volume, even if competitive.

      Focus on:
      - Core problem/solution keywords (the PROBLEM they're solving)
      - Industry-defining category terms
      - Generic "how to" phrases related to the main problem

      NOT product features or specific tools (save for Tier 2/3)

      ═══════════════════════════════════════════════════════════════
      TIER 2: MEDIUM-COMPETITION (6 keywords, 3-5 words)
      ═══════════════════════════════════════════════════════════════
      Realistic wins within 6-12 months.

      Focus on:
      - Problem-solving phrases ("how to...")
      - Category + tool/software/platform
      - Specific use cases or methods

      ═══════════════════════════════════════════════════════════════
      TIER 3: LOW-COMPETITION LONG-TAIL (6 keywords, 5-8 words)
      ═══════════════════════════════════════════════════════════════
      Quick wins - very specific, lower volume but high intent.

      Focus on:
      - Specific features + use case
      - Technology + category + descriptor
      - Very precise user needs

      CRITICAL: Focus on keywords where users want to DO what this product does.
      - If product validates ideas → include "validate idea", NOT "generate idea"
      - If product creates invoices → include "create invoice", NOT "send invoice"
      - If product tracks time → include "time tracking", NOT "analyze productivity"

      Return ONLY the keywords, one per line, without numbering or extra explanation.
      Focus on keywords with commercial or informational intent.
    PROMPT

    response = client.chat(
      messages: [ { role: "user", content: prompt } ],
      system_prompt: "You are an expert SEO strategist who generates keyword ideas based on actual website content.",
      max_tokens: 2000,
      temperature: 0.7
    )

    if response[:success]
      parse_keywords(response[:content])
    else
      Rails.logger.error "Seed generation failed: #{response[:error]}, using fallback"
      fallback_seeds(domain_data)
    end
  end

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

  def parse_keywords(content)
    keywords = content.split("\n")
                     .map { |line| line.strip }
                     .map { |line| line.gsub(/^\d+[\.\)]\s*/, "") }
                     .map { |line| line.gsub(/^[-*•]\s*/, "") }
                     .select { |line| line.length > 0 && line.length < 100 }
                     .map(&:downcase)

    keywords.uniq
  end

  def fallback_seeds(description)
    Rails.logger.warn "Using fallback: generating basic seeds from description/domain"

    seeds = []

    # If description is empty, try to extract from domain name
    if description.blank? || description.strip.empty?
      Rails.logger.warn "Description is empty, using domain name for fallback"
      domain_name = extract_domain_name_from_url(@domain)
      description = "#{domain_name} #{@niche}" if @niche.present?
      description = domain_name if description.blank?
    end

    # Extract key terms from description
    words = description.downcase.split(/\W+/)
    common_words = %w[the a an and or but for with from about in on at to of is are was were be been being have has had do does did will would could should may might must can]
    key_terms = words.reject { |w| common_words.include?(w) || w.length < 3 }.uniq

    # Generate basic seed variations
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

    # Add domain-based seeds as absolute fallback
    domain_name = extract_domain_name_from_url(@domain)
    if domain_name.present?
      seeds << domain_name
      seeds << "#{domain_name} alternative"
      seeds << "#{domain_name} review"
    end

    Rails.logger.info "Fallback generated #{seeds.compact.uniq.size} seeds"
    seeds.compact.uniq.first(20)
  end

  def extract_domain_name_from_url(url)
    # Extract domain name from URL (e.g., "signallab" from "https://signallab.app")
    uri = URI.parse(url)
    host = uri.host.gsub(/^www\./, "")
    host.split(".").first
  rescue
    "tool"
  end
end
