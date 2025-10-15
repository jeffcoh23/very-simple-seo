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
      # Build a simple search query based on what the site does
      search_query = build_search_query(domain_data)

      Rails.logger.info "Searching for competitors with query: #{search_query}"
      scraper = SerpResearchService.new(search_query)
      all_serp_results = scraper.search_results_only

      if all_serp_results.empty?
        Rails.logger.warn "No search results found"
        return []
      end

      Rails.logger.info "Found #{all_serp_results.size} search results"

      # Extract unique domains - minimal filtering, let AI and user curate
      user_domain_host = URI(@domain).host.gsub(/^www\./, '')

      candidate_domains = all_serp_results.map do |result|
        next unless result[:url]

        uri = URI(result[:url])
        host = uri.host.gsub(/^www\./, '')
        domain = "#{uri.scheme}://#{uri.host}"

        # Skip only the user's own domain
        next if host == user_domain_host

        {
          domain: domain,
          title: result[:title],
          description: result[:snippet],
          source: 'auto_detected'
        }
      end.compact.uniq { |c| c[:domain] }

      Rails.logger.info "Found #{candidate_domains.size} candidate competitors, filtering with AI..."

      # Use AI to intelligently filter competitors
      competitor_domains = filter_competitors_with_ai(candidate_domains, domain_data)

      Rails.logger.info "Detected #{competitor_domains.size} likely competitors for user curation"
      competitor_domains
    rescue => e
      Rails.logger.error "Competitor detection failed: #{e.message}"
      Rails.logger.error e.backtrace.first(3).join("\n")
      []
    end
  end

  def build_search_query(domain_data)
    # Get main topic from H1 or title
    raw_topic = domain_data[:h1s]&.first || domain_data[:title] || ""

    # Clean it up - remove the site name/branding
    topic = raw_topic.split('|').first.strip

    # Don't use overly generic niches - use the actual topic instead
    # Generic niches like "SaaS", "App", "Software" are too broad
    generic_niches = %w[saas software app platform tool service business]

    if @niche.present? && !generic_niches.include?(@niche.downcase)
      # Niche is specific enough, use it
      search_term = @niche
    else
      # Use the actual topic from the site (what they DO)
      search_term = topic
    end

    # If search term is still too short/generic, use first few meaningful words
    if search_term.split.size < 2
      # Fall back to first H2 or meta description for context
      search_term = domain_data[:h2s]&.first || domain_data[:meta_description] || search_term
      search_term = search_term.split(/[.|,]/).first.strip  # Take first sentence
    end

    search_term
  end

  def filter_competitors_with_ai(candidates, domain_data)
    return candidates if candidates.empty?

    # Build prompt with user's domain context and candidate list
    user_description = domain_data[:h1s]&.first || domain_data[:title] || "website"

    candidates_list = candidates.map.with_index do |c, i|
      "#{i + 1}. #{c[:domain]}\n   Title: #{c[:title]}\n   Description: #{c[:description]}"
    end.join("\n\n")

    prompt = <<~PROMPT
      I'm analyzing competitors for: #{@domain}
      What they do: #{user_description}

      Here are potential competitors from Google's related sites:

      #{candidates_list}

      For each site, determine if it's a LIKELY COMPETITOR (actual competing product/service) or NOT A COMPETITOR (aggregator, news site, blog, directory, review site, etc.).

      Return ONLY a JSON array with the numbers of likely competitors:
      ["1", "3", "5"]

      Include sites that:
      - Offer a similar product/service
      - Serve the same target audience
      - Solve similar problems

      Exclude sites that are:
      - News/blog sites (even if they cover the topic)
      - Aggregator/directory sites (alternatives.to, g2.com, etc.)
      - Review sites
      - General business tools (not specific to the niche)
      - Forums or communities
    PROMPT

    client = Ai::ClientService.for_keyword_analysis
    response = client.chat(
      messages: [{ role: "user", content: prompt }],
      system_prompt: "You are an expert at identifying competitive products and filtering out non-competitive sites.",
      max_tokens: 500,
      temperature: 0.3  # Lower temperature for more consistent filtering
    )

    return candidates unless response[:success]

    # Parse the JSON response
    begin
      json_str = response[:content][/\[.*\]/m]
      return candidates unless json_str

      selected_indices = JSON.parse(json_str).map(&:to_i)

      # Return the selected competitors
      selected = candidates.select.with_index { |_, i| selected_indices.include?(i + 1) }

      # If AI filtered out everything, return top candidates as fallback
      selected.any? ? selected : candidates.first(5)
    rescue JSON::ParserError => e
      Rails.logger.error "Failed to parse AI competitor filter response: #{e.message}"
      candidates  # Return all on parse error
    end
  end

  def generate_seeds(domain_data, competitors)
    # Use SeedKeywordGenerator in raw domain mode (no project yet)
    competitor_domains = competitors.map { |c| c[:domain] }

    generator = SeedKeywordGenerator.new(
      @domain,
      niche: @niche,
      competitors: competitor_domains
    )

    generator.generate
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
