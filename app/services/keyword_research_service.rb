# app/services/keyword_research_service.rb
# Main orchestration service for keyword research
class KeywordResearchService
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

    Rails.logger.info "Expanded to #{all_expanded.size} keywords before filtering"

    # Filter for relevance using AI
    filter = KeywordRelevanceFilter.new(@project)
    relevant_keywords = filter.filter(all_expanded.uniq)

    # Add filtered keywords
    relevant_keywords.each { |kw| add_keyword(kw, source: "expansion") }

    Rails.logger.info "After expansion and filtering: #{@keywords.size} unique keywords"
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

  def add_keyword(keyword, source: "unknown")
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
      intent: nil
    }

    @keywords[keyword][:sources] << source unless @keywords[keyword][:sources].include?(source)
  end

  def save_keywords
    Rails.logger.info "Step 6: Saving top 30 keywords to database..."

    # Sort by opportunity score (highest first), treating nil as 0
    sorted = @keywords.values.sort_by { |kw| -(kw[:opportunity] || 0) }

    # Save top 30
    top_30 = sorted.first(30)

    top_30.each do |kw_data|
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

    Rails.logger.info "Saved #{top_30.size} keywords"
  end
end
