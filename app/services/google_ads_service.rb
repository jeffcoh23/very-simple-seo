#!/usr/bin/env ruby
# frozen_string_literal: true

# Google Ads API Service for Keyword Research
# Fetches real search volume, CPC, and competition data

require "net/http"
require "json"
require "uri"

class GoogleAdsService
  # Google Ads API requires OAuth setup
  # Follow setup guide: https://developers.google.com/google-ads/api/docs/first-call/overview

  def initialize
    @developer_token = ENV["GOOGLE_ADS_DEVELOPER_TOKEN"]
    @client_id = ENV["GOOGLE_ADS_CLIENT_ID"]
    @client_secret = ENV["GOOGLE_ADS_CLIENT_SECRET"]
    @refresh_token = ENV["GOOGLE_ADS_REFRESH_TOKEN"]
    @customer_id = ENV["GOOGLE_ADS_CUSTOMER_ID"] # Your Google Ads customer ID (without dashes)
    @access_token = nil
  end

  def get_keyword_metrics(keywords)
    # Keywords can be array or single keyword
    keywords = [ keywords ] unless keywords.is_a?(Array)

    if !credentials_present?
      puts "  ⚠️  Google Ads API not configured (using heuristics)"
      return nil
    end

    begin
      refresh_access_token unless @access_token

      # Call Google Ads API to get keyword ideas and metrics
      results = fetch_keyword_ideas(keywords)

      # Parse and return metrics
      parse_keyword_metrics(results)
    rescue => e
      puts "  ⚠️  Google Ads API error: #{e.message}"
      nil
    end
  end

  private

  def credentials_present?
    @developer_token && @client_id && @client_secret && @refresh_token && @customer_id
  end

  def refresh_access_token
    uri = URI("https://oauth2.googleapis.com/token")

    request = Net::HTTP::Post.new(uri)
    request.set_form_data(
      "client_id" => @client_id,
      "client_secret" => @client_secret,
      "refresh_token" => @refresh_token,
      "grant_type" => "refresh_token"
    )

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    data = JSON.parse(response.body)

    if data["error"]
      raise "OAuth error: #{data['error_description']}"
    end

    @access_token = data["access_token"]
  end

  def fetch_keyword_ideas(keywords)
    # Use GenerateKeywordIdeas endpoint
    # https://developers.google.com/google-ads/api/reference/rpc/v16/KeywordPlanIdeaService

    uri = URI("https://googleads.googleapis.com/v16/customers/#{@customer_id}/keywordPlanIdeas:generateKeywordIdeas")

    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{@access_token}"
    request["developer-token"] = @developer_token
    request["Content-Type"] = "application/json"

    # Request body
    request.body = {
      keywordSeed: {
        keywords: keywords
      },
      geoTargetConstants: [ "geoTargetConstants/2840" ], # United States
      language: "languageConstants/1000", # English
      includeAdultKeywords: false,
      keywordPlanNetwork: "GOOGLE_SEARCH"
    }.to_json

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, read_timeout: 30) do |http|
      http.request(request)
    end

    if response.code != "200"
      raise "API error (#{response.code}): #{response.body[0..500]}"
    end

    JSON.parse(response.body)
  end

  def parse_keyword_metrics(response)
    results = response["results"] || []

    metrics = {}

    results.each do |result|
      keyword = result.dig("text")
      next unless keyword

      # Extract metrics
      keyword_metrics = result["keywordIdeaMetrics"]
      next unless keyword_metrics

      # Monthly search volume (average over last 12 months)
      avg_monthly_searches = keyword_metrics.dig("avgMonthlySearches")&.to_i || 0

      # Competition level (LOW, MEDIUM, HIGH)
      competition = keyword_metrics.dig("competition") || "UNSPECIFIED"

      # Competition index (0-100)
      competition_index = keyword_metrics.dig("competitionIndex")&.to_i || 50

      # CPC bid ranges (in micros, need to divide by 1,000,000)
      low_top_of_page_bid_micros = keyword_metrics.dig("lowTopOfPageBidMicros")&.to_i || 0
      high_top_of_page_bid_micros = keyword_metrics.dig("highTopOfPageBidMicros")&.to_i || 0

      low_cpc = low_top_of_page_bid_micros / 1_000_000.0
      high_cpc = high_top_of_page_bid_micros / 1_000_000.0
      avg_cpc = (low_cpc + high_cpc) / 2.0

      metrics[keyword.downcase] = {
        volume: avg_monthly_searches,
        competition_level: competition,
        difficulty: competition_index, # 0-100 scale
        cpc: avg_cpc.round(2)
      }
    end

    metrics
  end
end
