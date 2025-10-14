# app/services/keyword_metrics_service.rb
# Estimates keyword metrics (volume, difficulty, CPC) using heuristics
# Optionally uses Google Ads API for real metrics when configured
class KeywordMetricsService
  def initialize(keyword, use_google_ads: false)
    @keyword = keyword.downcase.strip
    @use_google_ads = use_google_ads
  end

  def calculate
    # Try Google Ads API first if enabled
    if @use_google_ads
      real_metrics = fetch_google_ads_metrics
      return real_metrics if real_metrics
    end

    # Fall back to heuristics
    {
      volume: estimate_volume,
      difficulty: estimate_difficulty,
      cpc: estimate_cpc,
      intent: determine_intent,
      opportunity: nil # Will be calculated after metrics are set
    }
  end

  # Class method for batch fetching from Google Ads API
  def self.calculate_batch(keywords, use_google_ads: false)
    if use_google_ads
      google_ads = GoogleAdsService.new
      real_metrics = google_ads.get_keyword_metrics(keywords)

      if real_metrics
        # Return real metrics for each keyword
        return keywords.map do |kw|
          kw_lower = kw.downcase.strip
          if real_metrics[kw_lower]
            {
              keyword: kw_lower,
              volume: real_metrics[kw_lower][:volume],
              difficulty: real_metrics[kw_lower][:difficulty],
              cpc: real_metrics[kw_lower][:cpc],
              intent: new(kw_lower).send(:determine_intent),
              opportunity: nil
            }
          else
            # Fall back to heuristics for this keyword
            new(kw_lower).calculate
          end
        end
      end
    end

    # Fall back to heuristics for all keywords
    keywords.map { |kw| new(kw).calculate.merge(keyword: kw.downcase.strip) }
  end

  def self.calculate_opportunity(metrics)
    # Opportunity score: balance between volume and difficulty
    # Higher volume + lower difficulty = higher opportunity

    volume_score = normalize(metrics[:volume], max: 500) # Normalize to 0-100
    difficulty_inverse = 100 - metrics[:difficulty] # Invert difficulty

    # Weighted average (favor volume slightly)
    opportunity = (volume_score * 0.6) + (difficulty_inverse * 0.4)

    # Boost for good intent
    opportunity += 5 if ["informational", "educational"].include?(metrics[:intent])
    opportunity += 10 if metrics[:intent] == "commercial"

    # Penalty for very low volume
    opportunity -= 20 if metrics[:volume] < 50

    [[opportunity, 0].max, 100].min.round
  end

  private

  def fetch_google_ads_metrics
    google_ads = GoogleAdsService.new
    real_metrics = google_ads.get_keyword_metrics([@keyword])

    return nil unless real_metrics && real_metrics[@keyword]

    {
      volume: real_metrics[@keyword][:volume],
      difficulty: real_metrics[@keyword][:difficulty],
      cpc: real_metrics[@keyword][:cpc],
      intent: determine_intent,
      opportunity: nil
    }
  rescue => e
    Rails.logger.error "Google Ads API error for keyword '#{@keyword}': #{e.message}"
    nil
  end

  def estimate_volume
    # Simple heuristic based on keyword characteristics
    base = 100

    # Shorter keywords = higher volume usually
    base += (50 - @keyword.split.size * 10) if @keyword.split.size <= 5

    # Common topics
    base += 200 if @keyword.include?("seo") || @keyword.include?("marketing")
    base += 150 if @keyword.include?("startup") || @keyword.include?("business")
    base += 100 if @keyword.include?("content") || @keyword.include?("article")

    # Question keywords = medium volume
    base += 50 if @keyword.start_with?("how to", "what is", "why", "when")

    # Long-tail = lower volume
    base -= @keyword.split.size * 20 if @keyword.split.size > 4

    # Tool/product keywords
    base += 100 if @keyword.include?("tool") || @keyword.include?("software") || @keyword.include?("generator")

    # Free = higher volume
    base += 80 if @keyword.include?("free")

    # Template/checklist = moderate volume
    base += 60 if @keyword.include?("template") || @keyword.include?("checklist")

    [base, 10].max # Minimum 10
  end

  def estimate_difficulty
    # Estimate how hard it is to rank (0 = easy, 100 = impossible)
    difficulty = 50 # Start at medium

    # Shorter keywords = harder
    difficulty += (5 - @keyword.split.size) * 10 if @keyword.split.size < 5

    # Competitive terms
    difficulty += 20 if @keyword.include?("best")
    difficulty += 15 if @keyword.split.size <= 2 # Very broad
    difficulty -= 15 if @keyword.split.size >= 5 # Long-tail = easier

    # Question keywords = easier (less competitive)
    difficulty -= 10 if @keyword.start_with?("how to", "what is", "why")

    # Tool/product = competitive
    difficulty += 10 if @keyword.include?("tool") || @keyword.include?("software")

    # Specific modifiers = easier
    difficulty -= 5 if @keyword.include?("free")
    difficulty -= 10 if @keyword.include?("template") || @keyword.include?("checklist")

    # Very specific = easier
    difficulty -= 15 if @keyword.split.size >= 6

    [[difficulty, 0].max, 100].min # Clamp between 0-100
  end

  def estimate_cpc
    # Rough CPC estimate (in reality, use Google Keyword Planner)
    base_cpc = 1.50

    base_cpc += 1.0 if @keyword.include?("startup") || @keyword.include?("business") || @keyword.include?("marketing")
    base_cpc += 0.50 if @keyword.include?("tool") || @keyword.include?("software")
    base_cpc -= 0.75 if @keyword.include?("free")
    base_cpc += 0.25 if @keyword.include?("best")
    base_cpc += 0.50 if @keyword.include?("seo")

    [base_cpc, 0.10].max.round(2)
  end

  def determine_intent
    # What is the user trying to do?

    return "navigational" if @keyword.include?("login") || @keyword.include?("sign up")
    return "commercial" if @keyword.include?("tool") || @keyword.include?("software") || @keyword.include?("best")
    return "transactional" if @keyword.include?("free") || @keyword.include?("online") || @keyword.include?("template")
    return "informational" if @keyword.start_with?("how to", "what is", "why", "when")
    return "educational" if @keyword.include?("guide") || @keyword.include?("tutorial") || @keyword.include?("framework")

    "mixed"
  end

  def self.normalize(value, max:)
    # Normalize value to 0-100 scale
    ((value.to_f / max) * 100).round
  end
end
