# app/services/google_suggestions_service.rb
# Fetches Google autocomplete suggestions for keyword expansion
class GoogleSuggestionsService
  def initialize(query)
    @query = query
  end

  def fetch
    uri = URI("http://suggestqueries.google.com/complete/search")
    params = { client: "firefox", q: @query }
    uri.query = URI.encode_www_form(params)

    begin
      response = Net::HTTP.get(uri)
      data = JSON.parse(response)
      data[1] || [] # Second element contains suggestions
    rescue => e
      Rails.logger.error "GoogleSuggestionsService error: #{e.message}"
      []
    end
  end
end
