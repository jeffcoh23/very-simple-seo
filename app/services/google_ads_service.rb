# frozen_string_literal: true

# Google Ads API Service for Keyword Research
# Fetches real search volume, CPC, and competition data using official gem
# Note: Google Ads gem is loaded in config/initializers/google_ads.rb

class GoogleAdsService
  # Google Ads API requires OAuth setup
  # Follow setup guide: https://developers.google.com/google-ads/api/docs/first-call/overview

  def initialize
    @client = nil
    @customer_id = ENV["GOOGLE_ADS_CUSTOMER_ID"]&.gsub(/[^0-9]/, '')
  end

  def get_keyword_metrics(keywords, location: 'United States', language: 'English')
    # Keywords can be array or single keyword
    keywords = [ keywords ] unless keywords.is_a?(Array)

    if !credentials_present?
      puts "  ⚠️  Google Ads API not configured (using heuristics)"
      return nil
    end

    begin
      # Initialize client if needed
      initialize_client unless @client

      # Google Ads API only supports 20 keywords per request
      # Batch keywords into groups of 20
      all_metrics = {}

      keywords.each_slice(20).with_index do |keyword_batch, index|
        # Add delay between batches to avoid rate limiting (except for first batch)
        sleep(5) if index > 0

        # Call Google Ads API with retry logic for rate limits
        retries = 0
        max_retries = 3

        begin
          results = fetch_keyword_ideas(keyword_batch, location: location, language: language)

          # Parse and merge metrics
          batch_metrics = parse_keyword_metrics(results)
          all_metrics.merge!(batch_metrics) if batch_metrics

        rescue Google::Ads::GoogleAds::Errors::GoogleAdsError => e
          # Check if it's a rate limit error
          if e.failure&.errors&.any? { |err| err.error_code.error_code == :quota_error }
            retries += 1
            if retries <= max_retries
              wait_time = 5 * retries # Exponential backoff: 5s, 10s, 15s
              Rails.logger.warn "Rate limit hit, retrying batch #{index + 1} in #{wait_time} seconds (attempt #{retries}/#{max_retries})"
              sleep(wait_time)
              retry
            else
              Rails.logger.error "Rate limit exceeded after #{max_retries} retries for batch #{index + 1}"
              raise # Re-raise to trigger outer exception handler
            end
          else
            raise # Re-raise non-rate-limit errors
          end
        end
      end

      all_metrics.empty? ? nil : all_metrics
    rescue Google::Ads::GoogleAds::Errors::GoogleAdsError => e
      puts "  ⚠️  Google Ads API error: #{e.message}"
      Rails.logger.error "Google Ads API error: #{e.class} - #{e.message}"

      # Log all error details
      if e.failure
        e.failure.errors.each do |error|
          Rails.logger.error "  Error code: #{error.error_code.error_code}"
          Rails.logger.error "  Message: #{error.message}"
          Rails.logger.error "  Trigger: #{error.trigger&.string_value}"
          puts "    Error: #{error.error_code.error_code} - #{error.message}"
        end
      end

      nil
    rescue => e
      puts "  ⚠️  Unexpected error: #{e.message}"
      Rails.logger.error "Unexpected error in GoogleAdsService: #{e.class} - #{e.message}\n#{e.backtrace.first(10).join("\n")}"
      nil
    end
  end

  private

  def credentials_present?
    ENV["GOOGLE_ADS_DEVELOPER_TOKEN"] &&
    ENV["GOOGLE_ADS_CLIENT_ID"] &&
    ENV["GOOGLE_ADS_CLIENT_SECRET"] &&
    ENV["GOOGLE_ADS_REFRESH_TOKEN"] &&
    @customer_id
  end

  def initialize_client
    # Configure the client using environment variables
    Google::Ads::GoogleAds::Config.new do |c|
      c.client_id = ENV['GOOGLE_ADS_CLIENT_ID']
      c.client_secret = ENV['GOOGLE_ADS_CLIENT_SECRET']
      c.refresh_token = ENV['GOOGLE_ADS_REFRESH_TOKEN']
      c.developer_token = ENV['GOOGLE_ADS_DEVELOPER_TOKEN']
      c.login_customer_id = @customer_id
    end

    @client = Google::Ads::GoogleAds::GoogleAdsClient.new
  end

  def fetch_keyword_ideas(keywords, location: 'United States', language: 'English')
    keyword_plan_idea_service = @client.service.keyword_plan_idea

    # Build the keyword seed using the client's resource factory
    keyword_seed = @client.resource.keyword_seed do |ks|
      ks.keywords += keywords
    end

    # Map location and language to Google constants
    # TODO: Make these configurable/dynamic
    geo_target = geo_target_constant_for_location(location)
    language_constant = language_constant_for_language(language)

    # Generate keyword ideas
    response = keyword_plan_idea_service.generate_keyword_ideas(
      customer_id: @customer_id,
      language: @client.path.language_constant(language_constant),
      geo_target_constants: [@client.path.geo_target_constant(geo_target)],
      keyword_plan_network: :GOOGLE_SEARCH,
      keyword_seed: keyword_seed
    )

    # Convert to array since it's a PagedEnumerable
    response.to_a
  end

  def parse_keyword_metrics(results)
    metrics = {}

    results.each do |result|
      keyword = result.text
      next unless keyword

      # Extract metrics
      keyword_metrics = result.keyword_idea_metrics
      next unless keyword_metrics

      # Monthly search volume (average over last 12 months)
      volume = keyword_metrics.avg_monthly_searches || 0

      # Competition level (LOW, MEDIUM, HIGH)
      competition = keyword_metrics.competition || :UNSPECIFIED

      # Competition index (0-100)
      competition_index = keyword_metrics.competition_index || 50

      # CPC bid ranges (in micros, need to divide by 1,000,000)
      low_cpc = (keyword_metrics.low_top_of_page_bid_micros || 0) / 1_000_000.0
      high_cpc = (keyword_metrics.high_top_of_page_bid_micros || 0) / 1_000_000.0
      avg_cpc = (low_cpc + high_cpc) / 2.0

      metrics[keyword.downcase] = {
        volume: volume,
        competition_level: competition.to_s,
        difficulty: competition_index, # 0-100 scale
        cpc: avg_cpc.round(2)
      }
    end

    metrics
  end

  # Map location names to Google Ads geo target constants
  def geo_target_constant_for_location(location)
    case location.downcase
    when 'united states', 'us', 'usa'
      2840
    when 'united kingdom', 'uk', 'gb'
      2826
    when 'canada', 'ca'
      2124
    when 'australia', 'au'
      2036
    else
      2840 # Default to United States
    end
  end

  # Map language names to Google Ads language constants
  def language_constant_for_language(language)
    case language.downcase
    when 'english', 'en'
      1000
    when 'spanish', 'es'
      1003
    when 'french', 'fr'
      1002
    when 'german', 'de'
      1001
    else
      1000 # Default to English
    end
  end
end
