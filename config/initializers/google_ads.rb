# frozen_string_literal: true

# Load Google Ads API gem
# This gem is not auto-required by Rails, so we load it here
begin
  require "google/ads/google_ads"
  Rails.logger.info "Google Ads API gem loaded successfully"
rescue LoadError => e
  Rails.logger.warn "Google Ads API gem not available: #{e.message}"
end
