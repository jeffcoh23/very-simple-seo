# app/services/seed_keyword_generator.rb
# Generates seed keywords using AI based on ACTUAL domain content
class SeedKeywordGenerator
  def initialize(project)
    @project = project
    @domain = project.domain
    @competitors = project.competitors.pluck(:domain)
  end

  def generate
    Rails.logger.info "Generating seed keywords for: #{@domain}"

    # If project already has domain_analysis, use it; otherwise scrape now
    domain_data = @project.domain_analysis || scrape_domain

    client = Ai::ClientService.for_keyword_analysis
    prompt = build_prompt(domain_data)

    response = client.chat(
      messages: [{ role: "user", content: prompt }],
      system_prompt: "You are an expert SEO strategist who generates keyword ideas based on actual website content.",
      max_tokens: 2000,
      temperature: 0.7
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

    # Store it on project for future use
    @project.update(domain_analysis: domain_data) if domain_data && !domain_data[:error]

    domain_data
  end

  def build_prompt(domain_data)
    competitor_list = @competitors.any? ? @competitors.join(", ") : "none detected"

    # Use REAL content from domain analysis
    title = domain_data[:title] || "Unknown"
    meta_desc = domain_data[:meta_description] || "Not available"
    h1s = domain_data[:h1s]&.join(", ") || "Not available"
    h2s = domain_data[:h2s]&.first(5)&.join(", ") || "Not available"

    <<~PROMPT
      I need seed keywords for an SEO content strategy.

      DOMAIN ANALYSIS (based on actual website content):
      Domain: #{@domain}
      Page Title: #{title}
      Meta Description: #{meta_desc}
      Main Headings (H1s): #{h1s}
      Content Topics (H2s): #{h2s}
      #{@project.niche.present? ? "Niche: #{@project.niche}" : ""}

      COMPETITORS:
      #{competitor_list}

      Based on the ACTUAL content from this website (not just the domain name), generate 15-20 seed keywords with a strategic MIX of competition levels:

      HIGH-VOLUME (5-7 keywords) - The "money" keywords, even if competitive:
      - Core product/service keywords (based on what the site actually offers)
      - Industry-defining terms

      MEDIUM-COMPETITION (5-7 keywords) - Realistic wins within 6-12 months:
      - Problem-solving keywords (how to...)
      - Comparison keywords
      - Educational keywords

      LOW-COMPETITION (5-7 keywords) - Quick wins, long-tail specific:
      - Tool/template keywords
      - Very specific use cases
      - Niche-specific variations

      Return ONLY the keywords, one per line, without numbering or extra explanation.
      Focus on keywords with commercial or informational intent.
      Mix broad generic terms with specific long-tail variations.
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
    if @project.niche.present?
      seeds << "#{@project.niche} guide"
      seeds << "best #{@project.niche}"
    end

    seeds.uniq.first(15)
  end
end
