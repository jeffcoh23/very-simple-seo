# app/services/seed_keyword_generator.rb
# Generates seed keywords using AI based on ACTUAL domain content
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
  end

  def generate
    Rails.logger.info "Generating seed keywords for: #{@domain}"

    # 1. Get or scrape YOUR domain data
    domain_data = @project&.domain_analysis || scrape_domain

    # 2. Get or scrape ALL competitor data (for richer seed generation)
    competitor_data = scrape_competitors

    # 3. Build prompt with YOUR domain + competitor insights
    client = Ai::ClientService.for_keyword_analysis
    prompt = build_prompt(domain_data, competitor_data)

    response = client.chat(
      messages: [{ role: "user", content: prompt }],
      system_prompt: "You are an expert SEO strategist who generates keyword ideas based on actual website content.",
      max_tokens: 2000,
      temperature: 0.3
    )

    if response[:success]
      seeds = parse_keywords(response[:content])
      Rails.logger.info "Generated #{seeds.size} seed keywords"
      seeds
    else
      Rails.logger.error "Failed to generate seed keywords: #{response[:error]}"
      fallback_seeds(domain_data)
    end
  end

  private

  def scrape_domain
    Rails.logger.info "Scraping domain for content analysis..."
    service = DomainAnalysisService.new(@domain)
    domain_data = service.analyze

    # Store it on project for future use (if we have a project)
    @project&.update(domain_analysis: domain_data) if domain_data && !domain_data[:error]

    domain_data
  end

  def scrape_competitors
    return [] if @competitors.empty?

    Rails.logger.info "Scraping #{@competitors.size} competitors for seed keyword generation..."

    competitor_data = []

    @competitors.each do |competitor_domain|
      Rails.logger.info "  Scraping #{competitor_domain}..."
      service = DomainAnalysisService.new(competitor_domain)
      data = service.analyze

      if data && !data[:error]
        competitor_data << data
      end

      sleep 1 # Be nice to servers
    end

    competitor_data
  end

  def build_prompt(domain_data, competitor_data = [])
    # Use REAL content from YOUR domain analysis
    title = domain_data[:title] || "Unknown"
    meta_desc = domain_data[:meta_description] || "Not available"
    h1s = domain_data[:h1s]&.join(", ") || "Not available"
    h2s = domain_data[:h2s]&.first(5)&.join(", ") || "Not available"

    # Build competitor insights section
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
      I need SEED keywords for an SEO content strategy. These are FOUNDATIONAL terms that will be expanded later.

      YOUR DOMAIN ANALYSIS (based on actual website content):
      Domain: #{@domain}
      Page Title: #{title}
      Meta Description: #{meta_desc}
      Main Headings (H1s): #{h1s}
      Content Topics (H2s): #{h2s}
      #{@niche.present? ? "Niche: #{@niche}" : ""}
      #{competitor_insights}

      YOUR TASK:
      Extract 15-20 SHORT, BROAD seed keywords (1-5 words) by identifying:
      1. The main PROBLEM your domain solves (e.g., "validate business", "idea validation")
      2. The core TOPICS in your headings (extract key noun phrases)
      3. What ACTIONS users want to take (e.g., "generate ideas", "test startup")
      4. Related CONCEPTS from the industry (look at competitor topics for inspiration)
      5. KEYWORD GAPS - topics competitors cover that you should target too

      IMPORTANT RULES:
      - Keep it SHORT: 1-5 words per keyword (prefer 2-3 words)
      - Extract from ACTUAL content, don't invent generic terms
      - Focus on searchable NOUNS and VERBS ("validate business" not "business validation tool")
      - Include variations (e.g., "business idea", "startup idea", "entrepreneurial idea")
      - Think: what would someone type in Google BEFORE they know this product exists?

      GOOD EXAMPLES:
      - "business idea", "startup idea", "validate business", "idea validation"
      - "customer persona", "market research", "business plan"
      - "startup feedback", "test idea", "validate startup"

      BAD EXAMPLES:
      - "business idea validation tool" (too specific, mentions "tool")
      - "ai-driven startup validation" (too specific, mentions technology)
      - "how to validate a business idea" (full question, not a seed)

      Return ONLY the keywords, one per line, without numbering or explanation.
    PROMPT
  end

  def parse_keywords(content)
    # Extract keywords from AI response
    # Remove numbering, bullets, extra whitespace
    keywords = content.split("\n")
                     .map { |line| line.strip }
                     .map { |line| line.gsub(/^\d+[\.\)]\s*/, '') } # Remove "1. " or "1) "
                     .map { |line| line.gsub(/^[-*•]\s*/, '') } # Remove bullets
                     .select { |line| line.length > 0 && line.length < 100 }
                     .map(&:downcase)
                     .select { |line| line.split.size >= 1 && line.split.size <= 5 } # Enforce 1-5 words for seeds

    keywords.uniq
  end

  def fallback_seeds(domain_data)
    # Fallback seeds if AI fails - use domain content
    Rails.logger.warn "Using fallback seed keywords from domain content"

    seeds = []

    # Use H1s and H2s as seeds
    seeds += domain_data[:h1s]&.map(&:downcase) || []
    seeds += domain_data[:h2s]&.first(10)&.map(&:downcase) || []

    # Use sitemap keywords
    seeds += domain_data[:sitemap_keywords] || []

    # Extract domain name for generic seeds
    begin
      uri = URI(@domain)
      domain_name = uri.host.gsub(/^www\./, '').split('.').first

      seeds += [
        "#{domain_name}",
        "what is #{domain_name}",
        "how to use #{domain_name}",
        "#{domain_name} alternative",
        "#{domain_name} review"
      ]
    rescue
      seeds += ["seo tool", "content generator", "keyword research"]
    end

    # Add niche-specific seeds
    if @niche.present?
      seeds << "#{@niche} guide"
      seeds << "best #{@niche}"
    end

    seeds.uniq.first(15)
  end
end
