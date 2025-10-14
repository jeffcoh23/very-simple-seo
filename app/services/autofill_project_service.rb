# app/services/autofill_project_service.rb
# Orchestrates domain analysis and competitor detection to auto-fill project form
class AutofillProjectService
  # Domains to exclude from competitor detection (aggregators, forums, social media)
  BLOCKED_DOMAINS = %w[
    reddit.com quora.com stackoverflow.com medium.com
    facebook.com twitter.com linkedin.com youtube.com
    wikipedia.org instagram.com pinterest.com github.com
    tiktok.com discord.com telegram.org
  ].freeze

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
    # Use the main topic from H1s or title to search for competitors
    # Clean up the search query - remove site name, just use the core topic
    raw_query = domain_data[:h1s]&.first || domain_data[:title] || extract_domain_name

    # Remove the domain name from the query to get generic topic
    # e.g., "Business Idea Validation Tool | SignalLab" → "Business Idea Validation Tool"
    base_query = raw_query.split('|').first.strip

    Rails.logger.info "Detecting competitors for: #{base_query}"

    begin
      all_serp_results = []

      # Strategy 1: Search with the main topic
      Rails.logger.info "Strategy 1: Searching for '#{base_query}'"
      scraper = SerpResearchService.new(base_query)
      all_serp_results.concat(scraper.search_results_only)

      # Strategy 2: Search for alternatives (if niche provided)
      if @niche.present?
        alternatives_query = "#{@niche} alternatives"
        Rails.logger.info "Strategy 2: Searching for '#{alternatives_query}'"
        scraper = SerpResearchService.new(alternatives_query)
        all_serp_results.concat(scraper.search_results_only)

        # Strategy 3: Search for best/top tools
        best_query = "best #{@niche} tools"
        Rails.logger.info "Strategy 3: Searching for '#{best_query}'"
        scraper = SerpResearchService.new(best_query)
        all_serp_results.concat(scraper.search_results_only)
      end

      if all_serp_results.empty?
        Rails.logger.warn "No search results found for competitor detection"
        return []
      end

      Rails.logger.info "Found #{all_serp_results.size} total search results across all strategies"

      # Extract unique domains with filtering
      user_domain_host = URI(@domain).host.gsub(/^www\./, '')

      competitor_domains = all_serp_results.map do |result|
        next unless result[:url]

        uri = URI(result[:url])
        host = uri.host.gsub(/^www\./, '')
        domain = "#{uri.scheme}://#{uri.host}"

        # Skip if it's the user's own domain
        next if host == user_domain_host

        # Skip if it's a blocked domain (aggregators, forums, social media)
        next if blocked_domain?(host)

        {
          domain: domain,
          title: result[:title],
          source: 'auto_detected'
        }
      end.compact.uniq { |c| c[:domain] }.first(15)

      Rails.logger.info "Detected #{competitor_domains.size} competitors after filtering"
      competitor_domains
    rescue => e
      Rails.logger.error "Competitor detection failed: #{e.message}"
      Rails.logger.error e.backtrace.first(3).join("\n")
      []
    end
  end

  def blocked_domain?(host)
    # Check if the host matches any blocked domain
    BLOCKED_DOMAINS.any? { |blocked| host.downcase.include?(blocked) }
  end

  def generate_seeds(domain_data, competitors)
    # Build prompt using REAL domain content
    client = Ai::ClientService.for_keyword_analysis

    competitor_list = competitors.map { |c| c[:domain] }.join(", ")
    competitor_list = "none detected" if competitor_list.empty?

    prompt = <<~PROMPT
      I need seed keywords for an SEO content strategy.

      DOMAIN ANALYSIS:
      Domain: #{@domain}
      Title: #{domain_data[:title]}
      Meta Description: #{domain_data[:meta_description]}
      Main Topics (H1s): #{domain_data[:h1s]&.join(', ')}
      Content Themes (H2s): #{domain_data[:h2s]&.first(5)&.join(', ')}
      #{@niche.present? ? "Niche: #{@niche}" : ""}

      COMPETITORS:
      #{competitor_list}

      Based on the ACTUAL content from this website, generate 15-20 seed keywords with a strategic MIX of competition levels:

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

    response = client.chat(
      messages: [{ role: "user", content: prompt }],
      system_prompt: "You are an expert SEO strategist who generates keyword ideas based on actual website content.",
      max_tokens: 2000,
      temperature: 0.7
    )

    if response[:success]
      parse_keywords(response[:content])
    else
      # Fallback to domain data keywords
      fallback_seeds(domain_data)
    end
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

  def fallback_seeds(domain_data)
    seeds = []

    # Use H1s and H2s as seeds
    seeds += domain_data[:h1s]&.map(&:downcase) || []
    seeds += domain_data[:h2s]&.first(10)&.map(&:downcase) || []

    # Use sitemap keywords
    seeds += domain_data[:sitemap_keywords] || []

    # Add some generic ones based on domain name
    domain_name = extract_domain_name
    seeds += [
      domain_name,
      "#{domain_name} guide",
      "how to use #{domain_name}",
      "#{domain_name} review"
    ]

    seeds.uniq.first(15)
  end

  def extract_domain_name
    URI(@domain).host.gsub(/^www\./, '').split('.').first
  rescue
    "tool"
  end
end
