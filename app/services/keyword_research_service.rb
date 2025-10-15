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
  end

  def perform
    Rails.logger.info "Starting keyword research for project: #{@project.name}"

    # 1. Generate seed keywords from project domain + competitors
    generate_seed_keywords

    # 2. Expand via Google autocomplete, PAA, related searches
    expand_keywords

    # 3. Mine Reddit topics (DISABLED - too noisy, creates ultra long-tail keywords with no volume)
    # mine_reddit

    # 4. Scrape competitor sitemaps and pages
    analyze_competitors

    # 5. Calculate metrics (heuristics)
    calculate_metrics

    # 6. Save top 30 keywords to database
    save_keywords

    # 7. Mark research as completed
    @keyword_research.update!(
      status: :completed,
      total_keywords_found: @keywords.size,
      completed_at: Time.current
    )

    Rails.logger.info "Keyword research completed. Found #{@keywords.size} keywords, saved top 30."
  end

  private

  def generate_seed_keywords
    Rails.logger.info "Step 1: Generating seed keywords..."

    # Use project.seed_keywords if user provided them, otherwise generate
    if @project.seed_keywords.present? && @project.seed_keywords.any?
      Rails.logger.info "Using #{@project.seed_keywords.size} user-provided seed keywords"
      seeds = @project.seed_keywords
    else
      Rails.logger.info "Generating seed keywords from domain content..."
      generator = SeedKeywordGenerator.new(@project)
      seeds = generator.generate
    end

    # Store seeds in keyword_research record
    @keyword_research.update!(seed_keywords: seeds)

    # Add each seed to our keywords hash
    seeds.each { |seed| add_keyword(seed, source: "seed") }

    Rails.logger.info "Using #{seeds.size} seed keywords"
  end

  def expand_keywords
    Rails.logger.info "Step 2: Expanding keywords..."

    all_expanded = []

    @keyword_research.seed_keywords.each do |seed|
      Rails.logger.info "  Expanding: #{seed}"

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

    all_expanded = all_expanded.uniq
    Rails.logger.info "Expanded to #{all_expanded.size} keywords before filtering"

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
        @keywords[kw][:opportunity] = KeywordMetricsService.calculate_opportunity(metrics)
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
        data[:opportunity] = KeywordMetricsService.calculate_opportunity(metrics)
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

    # Combine key content elements into contextual summary
    [
      domain_data[:title],
      domain_data[:meta_description],
      domain_data[:h1s]&.first(3)&.join(". "),
      domain_data[:h2s]&.first(5)&.join(". ")
    ].compact.join(". ")
  end

  # Filter keywords by semantic similarity to domain context
  def filter_by_semantic_similarity(keywords)
    return keywords if keywords.empty?

    domain_context = build_domain_context
    similarity_service = SemanticSimilarityService.new

    # Batch calculate similarity for all keywords
    similarity_results = similarity_service.batch_similarity(domain_context, keywords)

    # Filter and log rejected keywords
    filtered_keywords = []
    rejected_count = 0

    similarity_results.each do |result|
      if result[:similarity] >= SIMILARITY_THRESHOLD
        filtered_keywords << result[:keyword]
      else
        rejected_count += 1
        Rails.logger.info "  ⨯ Rejected '#{result[:keyword]}' (similarity: #{result[:similarity].round(3)})"
      end
    end

    Rails.logger.info "Semantic filter removed #{rejected_count} keywords (threshold: #{SIMILARITY_THRESHOLD})"

    filtered_keywords
  end
end
