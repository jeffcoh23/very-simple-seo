# app/services/keyword_research_service_v2.rb
# V2: Uses efficient SeedKeywordGeneratorV2 (2-3 API calls)
# NO grounding for expansion - uses existing fast/free methods only

class KeywordResearchServiceV2 < KeywordResearchService
  def initialize(keyword_research)
    super
    # No need for @grounding - we don't use it for expansion
  end

  private

  # Override: Use V2 seed generator (2-3 API calls)
  def generate_seed_keywords
    Rails.logger.info "Step 1: Generating V2 seed keywords with Grounding..."

    # Use project.seed_keywords if user provided them, otherwise generate with V2
    if @project.seed_keywords.present? && @project.seed_keywords.any?
      Rails.logger.info "Using #{@project.seed_keywords.size} user-provided seed keywords"
      seeds = @project.seed_keywords
    else
      Rails.logger.info "Generating V2 seeds from Grounding (max 3 API calls)..."
      generator = SeedKeywordGeneratorV2.new(@project)
      seeds = generator.generate
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
    seeds.each { |seed| add_keyword(seed, source: "seed_v2") }

    Rails.logger.info "Using #{seeds.size} V2 seed keywords"
  end

  # Override: NO grounding expansion - use existing fast/free methods only
  # This keeps us under 10 API calls per project (only 2-3 used for seeds)
  def expand_keywords
    Rails.logger.info "Step 2: Expanding keywords with existing methods (no Grounding)..."

    all_expanded = []

    @keyword_research.seed_keywords.each do |seed|
      Rails.logger.info "  Expanding: #{seed}"

      # Method 1: Google autocomplete suggestions (fast, free)
      suggestions = GoogleSuggestionsService.new(seed).fetch
      all_expanded.concat(suggestions)

      # Method 2: SERP scraping (PAA + Related Searches - fast, free)
      serp_scraper = SerpScraperService.new(seed)
      paa = serp_scraper.scrape_people_also_ask
      all_expanded.concat(paa)

      related = serp_scraper.scrape_related_searches
      all_expanded.concat(related)

      # Method 3: Google Ads expansion (gives metrics immediately - free API)
      if ENV["GOOGLE_ADS_DEVELOPER_TOKEN"].present?
        google_ads = GoogleAdsService.new
        ads_metrics = google_ads.get_keyword_metrics([seed])

        if ads_metrics
          ads_keywords = ads_metrics.keys
          all_expanded.concat(ads_keywords)
        end
      end

      sleep 2 # Be nice to Google
    end

    all_expanded = all_expanded.uniq
    Rails.logger.info "Expanded to #{all_expanded.size} keywords (no Grounding calls)"

    # Keep existing filtering pipeline
    semantically_filtered = filter_by_semantic_similarity(all_expanded)
    Rails.logger.info "After semantic filtering: #{semantically_filtered.size} keywords"

    # Layer 2: AI relevance filter with confidence levels
    filter = KeywordRelevanceFilter.new(@project)
    keywords_with_confidence = filter.filter_with_confidence(semantically_filtered)

    # Add keywords with their confidence metadata
    keywords_with_confidence.each do |keyword, confidence|
      next if confidence == "low" # Skip low confidence entirely

      add_keyword(keyword, source: "expansion_v2", confidence: confidence)
    end

    Rails.logger.info "After AI filtering: #{@keywords.size} keywords (V2 - no Grounding expansion)"
  end
end
