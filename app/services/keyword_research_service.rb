# app/services/keyword_research_service.rb
# Main orchestration service for keyword research
class KeywordResearchService
  # Thresholds for filtering
  SIMILARITY_THRESHOLD = 0.40 # Minimum semantic similarity (raised from 0.30 to filter wrong tool categories)

  def initialize(keyword_research)
    @keyword_research = keyword_research
    @project = keyword_research.project
    @keywords = {}
    @keyword_similarities = {} # Store semantic similarity scores for opportunity calculation
  end

  def perform
    Rails.logger.info "Starting keyword research for project: #{@project.name}"

    # NEW FLOW: Competitors inform seeds
    # 1. Scrape YOUR domain (if not cached)
    scrape_domain

    # 2. Discover and scrape competitors (Grounding)
    discover_and_scrape_competitors

    # 3. Generate seed keywords (using competitor insights)
    generate_seed_keywords

    # 4. Expand via Google autocomplete, PAA, related searches
    expand_keywords

    # 5. Mine Reddit topics (DISABLED - too noisy, creates ultra long-tail keywords with no volume)
    # mine_reddit

    # 6. Scrape competitor sitemaps and pages (additional source)
    analyze_competitors

    # 7. Calculate metrics (heuristics or Google Ads API)
    calculate_metrics

    # 8. Save top keywords to database (with filters)
    save_keywords

    # 9. Cluster similar keywords to avoid duplicates
    cluster_keywords

    # 10. Mark research as completed
    @keyword_research.update!(
      status: :completed,
      total_keywords_found: @keywords.size,
      completed_at: Time.current
    )

    Rails.logger.info "Keyword research completed. Found #{@keywords.size} keywords, saved top keywords."
  end

  private

  # Step 1: Scrape YOUR domain (if not already cached)
  def scrape_domain
    return if @project.domain_analysis.present?

    Rails.logger.info "Step 1: Scraping YOUR domain for content analysis..."
    service = DomainAnalysisService.new(@project.domain)
    domain_data = service.analyze

    if domain_data && !domain_data[:error]
      @project.update(domain_analysis: domain_data)
      Rails.logger.info "Domain analysis cached for future use"
    else
      Rails.logger.warn "Failed to scrape domain, will use fallback context"
    end
  end

  # Step 2: Discover and scrape competitors using Google Search + AI filtering
  def discover_and_scrape_competitors
    Rails.logger.info "Step 2: Discovering competitors with Google Search + AI filtering..."

    # Skip if user manually added competitors
    if @project.competitors.any?
      Rails.logger.info "Using #{@project.competitors.count} user-provided competitors"
      competitor_candidates = @project.competitors.map do |comp|
        { domain: comp.domain, title: comp.domain, description: "", source: "manual" }
      end
    else
      # Build search query based on domain content
      domain_data = @project.domain_analysis || {}
      search_query = build_search_query(domain_data)
      Rails.logger.info "Searching for competitors with query: #{search_query}"

      # Get Google Search results
      scraper = SerpResearchService.new(search_query)
      all_serp_results = scraper.search_results_only

      if all_serp_results.empty?
        Rails.logger.warn "No search results found"
        @competitor_data = []
        return
      end

      Rails.logger.info "Found #{all_serp_results.size} search results"

      # Extract candidate domains from SERP
      user_domain_host = URI(@project.domain).host.gsub(/^www\./, "")

      competitor_candidates = all_serp_results.map do |result|
        next unless result[:url]

        uri = URI(result[:url])
        host = uri.host.gsub(/^www\./, "")
        domain = "#{uri.scheme}://#{uri.host}"

        # Skip user's own domain
        next if host == user_domain_host

        {
          domain: domain,
          title: result[:title],
          description: result[:snippet],
          source: "auto_detected"
        }
      end.compact.uniq { |c| c[:domain] }

      Rails.logger.info "Found #{competitor_candidates.size} candidate competitors, filtering with AI..."

      # Use AI to filter out blogs/news/aggregators
      competitor_candidates = filter_competitors_with_ai(competitor_candidates, domain_data)
      Rails.logger.info "AI filtered to #{competitor_candidates.size} likely competitors"
    end

    # Scrape discovered competitors
    @competitor_data = []

    competitor_candidates.first(10).each do |candidate|
      domain = candidate[:domain]
      Rails.logger.info "  Scraping #{domain}..."
      service = DomainAnalysisService.new(domain)
      data = service.analyze

      if data && !data[:error]
        @competitor_data << data
      end

      sleep 1 # Be nice to servers
    end

    Rails.logger.info "Scraped #{@competitor_data.size} competitors successfully"
  end

  def generate_seed_keywords
    Rails.logger.info "Step 3: Generating seed keywords..."

    # Use project.seed_keywords if user provided them, otherwise generate
    if @project.seed_keywords.present? && @project.seed_keywords.any?
      Rails.logger.info "Using #{@project.seed_keywords.size} user-provided seed keywords"
      seeds = @project.seed_keywords
    else
      Rails.logger.info "Generating seed keywords from domain + competitor data..."

      generator = SeedKeywordGenerator.new(@project)
      seeds = generator.generate(@competitor_data)
    end

    # Store seeds in keyword_research record
    @keyword_research.update!(seed_keywords: seeds)

    # Calculate semantic similarity for seed keywords (for opportunity scoring)
    domain_context = build_domain_context
    similarity_service = SemanticSimilarityService.new
    seed_similarities = similarity_service.batch_similarity(domain_context, seeds)

    # Store seed similarities
    seed_similarities.each do |result|
      @keyword_similarities[result[:keyword]] = result[:similarity]
    end

    # Add each seed to our keywords hash
    seeds.each { |seed| add_keyword(seed, source: "seed") }

    Rails.logger.info "Using #{seeds.size} seed keywords"
  end

  def expand_keywords
    Rails.logger.info "Step 2: Expanding keywords..."

    all_expanded = []
    google_ads_suggestions = [] # Track Google Ads API suggestions separately

    @keyword_research.seed_keywords.each do |seed|
      Rails.logger.info "  Expanding: #{seed}"

      # Google Ads API keyword suggestions (BEST - includes metrics + variations)
      if ENV["GOOGLE_ADS_DEVELOPER_TOKEN"].present?
        google_ads = GoogleAdsService.new
        ads_metrics = google_ads.get_keyword_metrics([ seed ])

        if ads_metrics
          # Extract just the keywords from the metrics hash
          ads_keywords = ads_metrics.keys
          google_ads_suggestions.concat(ads_keywords)
          Rails.logger.info "    Google Ads API: #{ads_keywords.size} suggestions"
        end
      end

      # Google autocomplete suggestions
      suggestions = GoogleSuggestionsService.new(seed).fetch
      all_expanded.concat(suggestions)

      # SERP scraping (PAA + Related Searches)
      serp_scraper = SerpScraperService.new(seed)
      paa = serp_scraper.scrape_people_also_ask
      all_expanded.concat(paa)

      related = serp_scraper.scrape_related_searches
      all_expanded.concat(related)

      sleep 2 # Be nice to Google
    end

    # Combine all sources
    all_expanded.concat(google_ads_suggestions)
    all_expanded = all_expanded.uniq

    Rails.logger.info "Expanded to #{all_expanded.size} keywords (#{google_ads_suggestions.uniq.size} from Google Ads API)"

    # Semantic similarity filter (fast, catches obvious mismatches)
    semantically_filtered = filter_by_semantic_similarity(all_expanded)
    Rails.logger.info "After semantic filtering: #{semantically_filtered.size} keywords"

    # Add all semantically-filtered keywords
    # (No AI filter - it was inconsistent and expensive)
    # Rely on: semantic similarity + volume + opportunity for quality
    semantically_filtered.each do |keyword|
      add_keyword(keyword, source: "expansion")
    end

    Rails.logger.info "Added #{@keywords.size} keywords (will filter by volume >= 10 and opportunity after metrics)"
  end

  def mine_reddit
    Rails.logger.info "Step 3: Mining Reddit..."

    @keyword_research.seed_keywords.first(5).each do |seed| # Limit to first 5 seeds for Reddit
      miner = RedditMinerService.new(seed)
      reddit_keywords = miner.mine

      reddit_keywords.each { |kw| add_keyword(kw, source: "reddit") }

      sleep 2 # Be nice to Reddit
    end

    Rails.logger.info "After Reddit mining: #{@keywords.size} unique keywords"
  end

  def analyze_competitors
    return unless @project.competitors.any?

    Rails.logger.info "Step 4: Analyzing competitors..."

    analyzer = CompetitorAnalysisService.new(@project)
    competitor_data = analyzer.analyze_all

    competitor_data.each do |data|
      add_keyword(data[:keyword], source: data[:source])
    end

    Rails.logger.info "After competitor analysis: #{@keywords.size} unique keywords"
  end

  def calculate_metrics
    Rails.logger.info "Step 5: Calculating metrics for #{@keywords.size} keywords..."

    # Try to use Google Ads API for batch metrics (more efficient)
    use_google_ads = ENV["GOOGLE_ADS_DEVELOPER_TOKEN"].present?

    if use_google_ads && @keywords.size > 0
      Rails.logger.info "Attempting to fetch real metrics from Google Ads API..."

      # Batch fetch from Google Ads API
      keywords_array = @keywords.keys
      batch_metrics = KeywordMetricsService.calculate_batch(keywords_array, use_google_ads: true)

      # Apply metrics to our keywords hash
      batch_metrics.each do |metrics|
        kw = metrics[:keyword]
        next unless @keywords[kw]

        @keywords[kw][:volume] = metrics[:volume]
        @keywords[kw][:difficulty] = metrics[:difficulty]
        @keywords[kw][:cpc] = metrics[:cpc]
        @keywords[kw][:intent] = metrics[:intent]

        # Pass semantic similarity to opportunity calculation
        semantic_similarity = @keyword_similarities[kw]
        @keywords[kw][:opportunity] = KeywordMetricsService.calculate_opportunity(
          metrics,
          semantic_similarity: semantic_similarity
        )
      end
    else
      # Fall back to heuristics for each keyword
      @keywords.each do |kw, data|
        metrics_service = KeywordMetricsService.new(kw)
        metrics = metrics_service.calculate

        data[:volume] = metrics[:volume]
        data[:difficulty] = metrics[:difficulty]
        data[:cpc] = metrics[:cpc]
        data[:intent] = metrics[:intent]

        # Pass semantic similarity to opportunity calculation
        semantic_similarity = @keyword_similarities[kw]
        data[:opportunity] = KeywordMetricsService.calculate_opportunity(
          metrics,
          semantic_similarity: semantic_similarity
        )
      end
    end

    Rails.logger.info "Metrics calculated for all keywords"
  end

  def add_keyword(keyword, source: "unknown", confidence: nil)
    keyword = keyword.downcase.strip
    return if keyword.empty?
    return if keyword.length > 100 # Too long (likely sentence, not keyword)
    return if keyword.length < 3 # Too short

    @keywords[keyword] ||= {
      keyword: keyword,
      sources: [],
      volume: nil,
      difficulty: nil,
      cpc: nil,
      opportunity: nil,
      intent: nil,
      confidence: nil # Will store "high", "medium", or nil for seed/competitor keywords
    }

    @keywords[keyword][:sources] << source unless @keywords[keyword][:sources].include?(source)
    @keywords[keyword][:confidence] = confidence if confidence
  end

  def save_keywords
    Rails.logger.info "Step 6: Saving top keywords to database..."

    # Filter out keywords with very low or no search volume
    viable_keywords = @keywords.values.select do |kw|
      kw[:volume] && kw[:volume] >= 10
    end

    Rails.logger.info "Filtered to #{viable_keywords.size} keywords with volume >= 10"

    # Sort by opportunity score (highest first), treating nil as 0
    sorted = viable_keywords.sort_by { |kw| -(kw[:opportunity] || 0) }

    # Save ALL viable keywords (no cap for now - see full distribution)
    top_keywords = sorted

    top_keywords.each do |kw_data|
      @keyword_research.keywords.create!(
        keyword: kw_data[:keyword],
        volume: kw_data[:volume],
        difficulty: kw_data[:difficulty],
        opportunity: kw_data[:opportunity],
        cpc: kw_data[:cpc],
        intent: kw_data[:intent],
        sources: kw_data[:sources]
      )
    end

    Rails.logger.info "Saved #{top_keywords.size} keywords (filtered from #{@keywords.size} total, #{viable_keywords.size} with volume >= 10)"
  end

  # Build semantic "fingerprint" of domain for similarity matching
  # ENHANCED: Creates rich, detailed context for better semantic filtering
  # IMPROVED: Filters out low-quality seed keywords to prevent context pollution
  def build_domain_context
    domain_data = @project.domain_analysis

    # If no domain analysis, scrape it now (critical for semantic filtering)
    if domain_data.nil? || domain_data.empty?
      Rails.logger.info "No domain analysis found, scraping domain for context..."
      service = DomainAnalysisService.new(@project.domain)
      domain_data = service.analyze

      # Cache it for future use
      @project.update(domain_analysis: domain_data) if domain_data && !domain_data[:error]
    end

    # If scraping failed or returned minimal data, fall back to basic context
    if domain_data.nil? || domain_data.empty? || domain_data[:error]
      Rails.logger.warn "Could not scrape domain, using basic context (project name + niche)"
      return [ @project.name, @project.niche, @project.description ].compact.join(". ")
    end

    # Convert to symbol keys if needed (domain_analysis is stored with string keys in JSONB)
    domain_data = domain_data.deep_symbolize_keys if domain_data.is_a?(Hash)

    # Build context parts
    context_parts = []

    # 1. Core business description (what you do)
    context_parts << domain_data[:title] if domain_data[:title].present?
    context_parts << domain_data[:meta_description] if domain_data[:meta_description].present?

    # 2. Detailed problem/solution context
    # Add explicit statements about what the business does
    if @project.description.present?
      context_parts << "This business: #{@project.description}"
    end

    if @project.niche.present?
      context_parts << "Industry: #{@project.niche}"
    end

    # 3. Headings (if available - only for non-SPA sites)
    if domain_data[:h1s]&.any?
      context_parts << "Main topics: #{domain_data[:h1s].first(3).join(', ')}"
    end
    if domain_data[:h2s]&.any?
      context_parts << "Content areas: #{domain_data[:h2s].first(5).join(', ')}"
    end

    # 4. Sitemap keywords (good signal for SPA sites)
    if domain_data[:sitemap_keywords]&.any?
      context_parts << "Site sections: #{domain_data[:sitemap_keywords].first(10).join(', ')}"
    end

    # 5. IMPROVED: Filter seed keywords to include only high-quality ones
    # This prevents one bad seed from polluting the semantic context
    if @keyword_research&.seed_keywords&.any?
      filtered_seeds = filter_quality_seeds(@keyword_research.seed_keywords, domain_data)
      if filtered_seeds.any?
        context_parts << "Target keywords: #{filtered_seeds.join(', ')}"
        Rails.logger.info "Using #{filtered_seeds.size}/#{@keyword_research.seed_keywords.size} high-quality seeds for context"
      end
    end

    # 6. Project metadata as fallback
    if context_parts.size < 3
      Rails.logger.warn "Limited context available, adding fallback metadata"
      context_parts << @project.name
      context_parts << @project.niche if @project.niche.present?
    end

    context = context_parts.compact.join(". ")
    Rails.logger.info "Built domain context (#{context.length} chars): #{context.first(200)}..."
    context
  end

  # Filter seed keywords to remove outliers that don't match the core business
  # This prevents bad seeds from poisoning the semantic filter
  def filter_quality_seeds(seeds, domain_data)
    return seeds if seeds.size <= 3  # If very few seeds, use them all

    # Build a "core context" from just domain data (no seeds)
    core_context_parts = []
    core_context_parts << domain_data[:title] if domain_data[:title].present?
    core_context_parts << domain_data[:meta_description] if domain_data[:meta_description].present?
    core_context_parts << @project.description if @project.description.present?

    core_context = core_context_parts.compact.join(". ")
    return seeds if core_context.blank?  # No domain context available

    # Calculate similarity of each seed to core context
    similarity_service = SemanticSimilarityService.new
    seed_scores = similarity_service.batch_similarity(core_context, seeds)

    # Sort by similarity and take top 80% (filters out bottom 20% outliers)
    sorted_seeds = seed_scores.sort_by { |s| -s[:similarity] }
    cutoff_index = (seeds.size * 0.8).ceil

    filtered = sorted_seeds.first(cutoff_index).map { |s| s[:keyword] }

    # Log any rejected seeds
    rejected = seeds - filtered
    if rejected.any?
      Rails.logger.info "Filtered out #{rejected.size} low-quality seeds from context: #{rejected.join(', ')}"
    end

    filtered
  end

  # Filter keywords by semantic similarity to domain context
  def filter_by_semantic_similarity(keywords)
    return keywords if keywords.empty?

    domain_context = build_domain_context
    similarity_service = SemanticSimilarityService.new

    # Batch calculate similarity for all keywords
    similarity_results = similarity_service.batch_similarity(domain_context, keywords)

    # DON'T reset @keyword_similarities - we want to preserve seed similarities calculated earlier
    # @keyword_similarities already initialized in initialize() and populated in generate_seed_keywords()

    # Filter and log rejected keywords
    filtered_keywords = []
    rejected_count = 0

    similarity_results.each do |result|
      if result[:similarity] >= SIMILARITY_THRESHOLD
        filtered_keywords << result[:keyword]
        @keyword_similarities[result[:keyword]] = result[:similarity] # Store for opportunity calc
      else
        rejected_count += 1
        Rails.logger.info "  ⨯ Rejected '#{result[:keyword]}' (similarity: #{result[:similarity].round(3)})"
      end
    end

    Rails.logger.info "Semantic filter removed #{rejected_count} keywords (threshold: #{SIMILARITY_THRESHOLD})"

    filtered_keywords
  end

  # Build search query for competitor discovery
  def build_search_query(domain_data)
    # Get main topic from H1 or title
    raw_topic = domain_data[:h1s]&.first || domain_data[:title] || ""

    # Clean it up - remove site name/branding
    topic = raw_topic.split("|").first.strip

    # Don't use overly generic niches
    generic_niches = %w[saas software app platform tool service business]

    if @project.niche.present? && !generic_niches.include?(@project.niche.downcase)
      search_term = @project.niche
    else
      search_term = topic
    end

    # If search term is still too short/generic, use first H2 or meta description
    if search_term.split.size < 2
      search_term = domain_data[:h2s]&.first || domain_data[:meta_description] || search_term
      search_term = search_term.split(/[.|,]/).first.strip  # Take first sentence
    end

    search_term
  end

  # Filter competitor candidates with AI to remove blogs/news/aggregators
  def filter_competitors_with_ai(candidates, domain_data)
    return candidates if candidates.empty?

    user_description = domain_data[:h1s]&.first || domain_data[:title] || "website"

    candidates_list = candidates.map.with_index do |c, i|
      "#{i + 1}. #{c[:domain]}\n   Title: #{c[:title]}\n   Description: #{c[:description]}"
    end.join("\n\n")

    prompt = <<~PROMPT
      I'm analyzing competitors for: #{@project.domain}
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
      messages: [ { role: "user", content: prompt } ],
      system_prompt: "You are an expert at identifying competitive products and filtering out non-competitive sites.",
      max_tokens: 500,
      temperature: 0.3
    )

    return candidates unless response[:success]

    # Parse JSON response
    begin
      json_str = response[:content][/\[.*\]/m]
      return candidates unless json_str

      selected_indices = JSON.parse(json_str).map(&:to_i)
      selected = candidates.select.with_index { |_, i| selected_indices.include?(i + 1) }

      # If AI filtered out everything, return top candidates as fallback
      selected.any? ? selected : candidates.first(5)
    rescue JSON::ParserError => e
      Rails.logger.error "Failed to parse AI competitor filter response: #{e.message}"
      candidates
    end
  end

  # Step 9: Cluster similar keywords to avoid duplicates
  def cluster_keywords
    return unless @keyword_research.keywords.any?

    Rails.logger.info "Step 9: Clustering keywords..."

    clustering_service = KeywordClusterAssignmentService.new(@keyword_research)
    clustering_service.perform

    Rails.logger.info "Clustering complete"
  rescue => e
    Rails.logger.error "Clustering failed: #{e.message}"
    # Don't fail the whole research if clustering fails
  end
end
