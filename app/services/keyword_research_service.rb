# app/services/keyword_research_service.rb
# Main orchestration service for keyword research
class KeywordResearchService
  # Thresholds for filtering
  OPPORTUNITY_THRESHOLD_FOR_MEDIUM = 70 # Minimum opportunity score for medium confidence keywords
  SIMILARITY_THRESHOLD = 0.30 # Minimum semantic similarity (0-1 scale, tuned to 0.30 for balance)

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

    # 9. Mark research as completed
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

  # Step 2: Discover and scrape competitors using Grounding
  def discover_and_scrape_competitors
    Rails.logger.info "Step 2: Discovering and scrape competitors with Grounding..."

    # Skip if user manually added competitors
    if @project.competitors.any?
      Rails.logger.info "Using #{@project.competitors.count} user-provided competitors"
      competitor_domains = @project.competitors.pluck(:domain)
    else
      # Build rich context from domain analysis
      domain_data = @project.domain_analysis || {}

      # Use Grounding to discover competitors with rich context
      grounding = GoogleGroundingService.new

      # Build detailed query with actual business description
      query = build_competitor_discovery_query(domain_data)
      Rails.logger.info "Grounding query: #{query[0..200]}..."

      json_structure = [
        "competitor1.com",
        "competitor2.com",
        "competitor3.com"
      ].to_json

      result = grounding.search_json(query, json_structure_hint: json_structure)

      if result[:success]
        competitor_domains = parse_competitor_domains(result[:data])
        Rails.logger.info "Discovered #{competitor_domains.size} competitors via Grounding"

        # Log what was found for debugging
        competitor_domains.first(5).each do |domain|
          Rails.logger.info "  - #{domain}"
        end
      else
        Rails.logger.warn "Grounding competitor discovery failed: #{result[:error]}"
        competitor_domains = []
      end
    end

    # Scrape discovered competitors
    @competitor_data = []

    competitor_domains.first(10).each do |domain|
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
      Rails.logger.info "Generating seed keywords from domain + competitor insights..."

      # Extract competitor domains (not scraped data)
      competitor_domains = @competitor_data.map { |c| c[:url] || c[:domain] }.compact rescue []

      generator = SeedKeywordGenerator.new(@project)
      seeds = generator.generate_with_competitors(competitor_domains)
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
        ads_metrics = google_ads.get_keyword_metrics([seed])

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

    # Layer 1: Semantic similarity pre-filter (fast, catches obvious mismatches)
    semantically_filtered = filter_by_semantic_similarity(all_expanded)
    Rails.logger.info "After semantic filtering: #{semantically_filtered.size} keywords"

    # Layer 2: AI relevance filter with confidence levels
    filter = KeywordRelevanceFilter.new(@project)
    keywords_with_confidence = filter.filter_with_confidence(semantically_filtered)

    # Add keywords with their confidence metadata
    keywords_with_confidence.each do |keyword, confidence|
      next if confidence == "low" # Skip low confidence entirely

      # Add keyword with confidence metadata (we'll use this later for Option 2 filtering)
      add_keyword(keyword, source: "expansion", confidence: confidence)
    end

    Rails.logger.info "After AI filtering: #{@keywords.size} keywords (will apply Option 2 filter after metrics)"
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

    # Option 2 Filter: Apply confidence-based opportunity threshold
    # High confidence = keep (always)
    # Medium confidence + Opp > 70 = keep
    # Medium confidence + Opp ≤ 70 = remove
    # Low confidence = already removed earlier
    # No confidence (seed/competitor) = keep (trust the source)

    before_count = viable_keywords.size
    filtered_keywords = viable_keywords.select do |kw|
      confidence = kw[:confidence]

      if confidence == "high" || confidence.nil?
        # High confidence or no confidence (seed/competitor) = always keep
        true
      elsif confidence == "medium"
        # Medium confidence = only keep if high opportunity
        opportunity = kw[:opportunity] || 0
        keep = opportunity > OPPORTUNITY_THRESHOLD_FOR_MEDIUM

        unless keep
          Rails.logger.info "  ⨯ Filtered medium-confidence '#{kw[:keyword]}' (opp: #{opportunity})"
        end

        keep
      else
        # Low confidence should have been filtered already, but just in case
        false
      end
    end

    Rails.logger.info "Option 2 filter removed #{before_count - filtered_keywords.size} medium-confidence low-opportunity keywords"

    # Sort by opportunity score (highest first), treating nil as 0
    sorted = filtered_keywords.sort_by { |kw| -(kw[:opportunity] || 0) }

    # Save top 100 (or all if less than 100)
    top_keywords = sorted.first(100)

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
      return [@project.name, @project.niche, @project.description].compact.join(". ")
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

    # 5. Seed keywords (CRITICAL - these define the semantic space)
    if @keyword_research&.seed_keywords&.any?
      # Include ALL seed keywords, not just first 10 - they're the ground truth
      context_parts << "Target keywords: #{@keyword_research.seed_keywords.join(', ')}"
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

  # Build rich competitor discovery query for Grounding
  def build_competitor_discovery_query(domain_data)
    domain = @project.domain.gsub(%r{^https?://}, '').gsub(%r{^www\.}, '').gsub(%r{/$}, '')

    # Extract clean description from project description field
    # (May contain "Title: ... Description: ..." format)
    raw_description = @project.description.presence || "#{@project.name} - #{@project.niche}"

    # Try to extract just the description part if it's in "Description: X" format
    description = if raw_description.include?("Description:")
      raw_description.split("Description:").last.strip
    else
      raw_description
    end

    # Build query - ask for 30 competitors with relevance scores
    <<~QUERY
      Find up to 30 competitor websites for this business:
      #{description}

      Website: #{@project.domain}

      IMPORTANT: Only include websites where this service is their PRIMARY FOCUS or a CORE OFFERING.
      Do NOT include sites that only have this as a minor side feature or hidden tool.

      For each competitor, rate how relevant they are on a scale of 1-10 where:
      - 10 = Direct competitor, this is their main product/service
      - 7-9 = Very similar service, prominently featured on their site
      - 5-6 = Related service, but clearly part of their core offering
      - Below 5 = Don't include (side feature, not core focus)

      Return ONLY valid JSON (no markdown, no code blocks) in this exact format:
      [
        {
          "domain": "competitor1.com",
          "relevance_score": 9,
          "reason": "Brief reason"
        }
      ]

      Keep reasons concise (under 100 characters).
      Focus on finding competitors you haven't heard of before.
      Include both well-known and lesser-known competitors.
    QUERY
  end

  # Parse competitor domains from Grounding JSON response
  # Filters to only include competitors with relevance_score >= 7 (strict filtering for primary focus)
  def parse_competitor_domains(data)
    competitors = case data
    when Array
      # New format: array of objects with domain, relevance_score, reason
      if data.first.is_a?(Hash) && data.first.key?("domain")
        data.select { |c| c["relevance_score"].to_i >= 7 }
            .sort_by { |c| -c["relevance_score"].to_i }
            .map { |c| normalize_domain(c["domain"]) }
      else
        # Old format: array of strings
        data.map { |c| normalize_domain(c) }
      end
    when Hash
      (data["competitors"] || data["domains"] || []).map { |c| normalize_domain(c) }
    else
      []
    end

    competitors.compact.uniq.first(30) # Increased to 30 since we're filtering by score
  end

  # Normalize domain format
  def normalize_domain(competitor)
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
end
