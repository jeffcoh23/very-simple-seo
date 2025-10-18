# app/services/google_grounding_service.rb
# Wrapper for grounded search using different AI providers
# Supports: Gemini (google_search), Perplexity (web search), OpenAI (future)

class GoogleGroundingService
  # Default to Gemini for grounding
  DEFAULT_PROVIDER = :gemini_grounding

  def initialize(provider: DEFAULT_PROVIDER)
    @provider = provider
    @client = build_client
  end

  # Perform a grounded search and return structured results
  # @param query [String] The search query
  # @param max_tokens [Integer] Maximum response tokens
  # @return [Hash] { success: boolean, content: string, grounding_metadata: hash, error: string }
  def search(query, max_tokens: 8000)
    Rails.logger.info "GoogleGrounding: Searching '#{query[0..50]}...' (provider: #{@provider})"

    result = case @provider
    when :gemini_grounding
      search_with_gemini(query, max_tokens)
    when :perplexity
      search_with_perplexity(query, max_tokens)
    when :openai_search
      search_with_openai(query, max_tokens) # Future: OpenAI with web search
    else
      { success: false, error: "Unknown provider: #{@provider}" }
    end

    Rails.logger.info "GoogleGrounding: #{result[:success] ? 'Success' : 'Failed'}"
    result
  end

  # Request structured JSON response from grounded search
  # @param query [String] The search query
  # @param json_structure_hint [String] Example JSON structure to guide response format
  # @return [Hash] { success: boolean, data: parsed_json, grounding_metadata: hash, error: string }
  def search_json(query, json_structure_hint:)
    Rails.logger.info "GoogleGrounding: JSON search '#{query[0..100]}...'"

    prompt = "#{query}\n\nReturn ONLY valid JSON matching this structure:\n#{json_structure_hint}"

    begin
      # Call the appropriate chat method based on provider
      response = case @provider
      when :gemini_grounding
        @client.chat_with_grounding(
          messages: [{ role: "user", content: prompt }],
          max_tokens: 8000,
          temperature: 0.3
        )
      else
        @client.chat(
          messages: [{ role: "user", content: prompt }],
          max_tokens: 8000,
          temperature: 0.3
        )
      end

      # Check if chat call succeeded
      unless response[:success]
        Rails.logger.error "GoogleGrounding: Chat failed - #{response[:error]}"
        return { success: false, error: response[:error] }
      end

      content = response[:content].strip
      Rails.logger.info "GoogleGrounding: Content received (#{content.length} chars)"

      # Extract JSON from response (may have markdown code blocks)
      json_content = extract_json_from_response(content)

      parsed_data = JSON.parse(json_content)

      result = {
        success: true,
        data: parsed_data,
        grounding_metadata: extract_grounding_metadata(response[:raw_response]),
        raw_response: response[:raw_response]
      }

      Rails.logger.info "GoogleGrounding: JSON search successful (#{result[:grounding_metadata][:sources_count]} sources)"
      result

    rescue JSON::ParserError => e
      Rails.logger.error "GoogleGrounding: JSON parse error - #{e.message}"
      Rails.logger.error "Response content (first 1000 chars): #{content[0..1000]}"
      Rails.logger.error "Response content (last 500 chars): #{content[-500..-1]}" if content
      { success: false, error: "Invalid JSON response: #{e.message}", raw_content: content }
    rescue RubyLLM::UnauthorizedError => e
      Rails.logger.error "GoogleGrounding: Auth error - #{e.message}"
      { success: false, error: "Authentication failed: #{e.message}" }
    rescue RubyLLM::RateLimitError => e
      Rails.logger.warn "GoogleGrounding: Rate limit - #{e.message}"
      { success: false, error: "Rate limit exceeded: #{e.message}" }
    rescue => e
      Rails.logger.error "GoogleGrounding: Error - #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")
      { success: false, error: e.message }
    end
  end

  # Extract keywords from grounding search results
  # @param query [String] Query designed to find keywords
  # @return [Array<Hash>] Array of { keyword: string, source: string, relevance: float }
  def extract_keywords(query)
    result = search(query)
    return [] unless result[:success]

    keywords = parse_keywords_from_content(result[:content])

    # Add source metadata from grounding
    keywords.map do |kw|
      {
        keyword: kw,
        source: "grounding",
        grounding_sources: result[:grounding_metadata][:sources_count],
        confidence: calculate_keyword_confidence(result[:grounding_metadata])
      }
    end
  end

  # Discover competitor domains for a given niche/domain
  # @param domain [String] The domain to find competitors for
  # @param niche [String] The niche/industry
  # @return [Array<String>] Array of competitor URLs
  def discover_competitors(domain, niche)
    queries = [
      "competitors of #{domain}",
      "alternatives to #{domain}",
      "best #{niche} tools like #{domain}",
      "top #{niche} software companies"
    ]

    competitors = []

    queries.each do |query|
      result = search(query, max_tokens: 1000)
      next unless result[:success]

      # Extract URLs from content and grounding metadata
      urls = extract_urls_from_content(result[:content])
      competitors.concat(urls)

      sleep 1 # Be respectful
    end

    # Clean up and dedupe
    competitors.map { |url| normalize_domain(url) }
               .compact
               .uniq
               .reject { |url| url.include?(domain) } # Remove self
               .first(10) # Limit to top 10
  end

  private

  def build_client
    case @provider
    when :gemini_grounding
      Ai::ClientService.for_grounding_research
    when :perplexity
      Ai::ClientService.for_perplexity_search
    when :openai_search
      Ai::ClientService.for_openai_search
    else
      raise "Unknown provider: #{@provider}"
    end
  end

  # Gemini with google_search tool
  def search_with_gemini(query, max_tokens)
    response = @client.chat_with_grounding(
      messages: [{ role: "user", content: query }],
      max_tokens: max_tokens,
      temperature: 0.3 # Lower for factual searches
    )

    return { success: false, error: response[:error] } unless response[:success]

    {
      success: true,
      content: response[:content],
      grounding_metadata: extract_gemini_grounding_metadata(response),
      raw_response: response
    }
  rescue => e
    Rails.logger.error "Gemini search failed: #{e.message}"
    { success: false, error: e.message }
  end

  # Perplexity (has built-in web search)
  def search_with_perplexity(query, max_tokens)
    response = @client.chat(
      messages: [{ role: "user", content: query }],
      max_tokens: max_tokens,
      temperature: 0.3
    )

    return { success: false, error: response[:error] } unless response[:success]

    {
      success: true,
      content: response[:content],
      grounding_metadata: extract_perplexity_citations(response),
      raw_response: response
    }
  rescue => e
    Rails.logger.error "Perplexity search failed: #{e.message}"
    { success: false, error: e.message }
  end

  # OpenAI with future web search capability
  def search_with_openai(query, max_tokens)
    # Future: OpenAI may add web search tools
    response = @client.chat(
      messages: [{ role: "user", content: query }],
      max_tokens: max_tokens,
      temperature: 0.3
    )

    return { success: false, error: response[:error] } unless response[:success]

    {
      success: true,
      content: response[:content],
      grounding_metadata: { sources_count: 0, sources: [], note: "OpenAI web search not yet available" },
      raw_response: response
    }
  rescue => e
    Rails.logger.error "OpenAI search failed: #{e.message}"
    { success: false, error: e.message }
  end

  # Extract grounding metadata based on provider
  def extract_grounding_metadata(response)
    case @provider
    when :gemini_grounding
      extract_gemini_grounding_metadata(response)
    when :perplexity
      extract_perplexity_citations(response)
    else
      { sources_count: 0, sources: [], web_search_queries: [] }
    end
  end

  # Extract grounding metadata from Gemini response
  def extract_gemini_grounding_metadata(response)
    metadata = {
      sources_count: 0,
      web_search_queries: [],
      sources: []
    }

    # Response is a RubyLLM::Message object, not a hash
    if response&.respond_to?(:raw)
      raw = response.raw
      if raw.respond_to?(:body)
        body = raw.body
        body = JSON.parse(body) if body.is_a?(String)

        if body.is_a?(Hash)
          grounding = body.dig("candidates", 0, "groundingMetadata")
          if grounding
            metadata[:web_search_queries] = grounding["webSearchQueries"] || []
            metadata[:sources_count] = grounding.dig("groundingChunks")&.size || 0
            metadata[:sources] = extract_source_urls(grounding)
          end
        end
      end
    end

    metadata
  end

  # Extract citations from Perplexity response
  def extract_perplexity_citations(response)
    # Perplexity returns citations in response
    # Format: [1], [2], etc with citations array
    citations = response.dig(:raw_response, :citations) || []

    {
      sources_count: citations.size,
      sources: citations,
      web_search_queries: ["perplexity_automatic_search"],
      note: "Perplexity built-in search"
    }
  end

  # Extract source URLs from grounding metadata
  def extract_source_urls(grounding)
    return [] unless grounding && grounding["groundingChunks"]

    grounding["groundingChunks"].map do |chunk|
      chunk.dig("web", "uri")
    end.compact.uniq
  end

  # Parse keywords from AI response content
  # Expects AI to return keywords in a structured format
  def parse_keywords_from_content(content)
    keywords = []

    # Look for common keyword list patterns
    # e.g., "- keyword", "* keyword", "1. keyword", or JSON arrays

    # Try JSON first
    if content.include?("[") && content.include?("]")
      begin
        # Extract JSON array
        json_match = content.match(/\[.*?\]/m)
        if json_match
          parsed = JSON.parse(json_match[0])
          keywords.concat(parsed) if parsed.is_a?(Array)
        end
      rescue JSON::ParserError
        # Not JSON, continue
      end
    end

    # Try bullet points
    content.scan(/^[\s]*[-\*•]\s*(.+)$/m).each do |match|
      kw = match[0].strip.gsub(/["']/, "").split(",").first
      keywords << kw if kw && kw.length > 3 && kw.length < 100
    end

    # Try numbered lists
    content.scan(/^\s*\d+\.\s*(.+)$/m).each do |match|
      kw = match[0].strip.gsub(/["']/, "").split(",").first
      keywords << kw if kw && kw.length > 3 && kw.length < 100
    end

    # Clean up and dedupe
    keywords.map(&:strip)
            .map(&:downcase)
            .reject { |kw| kw.empty? || kw.length < 3 }
            .uniq
  end

  # Extract URLs from content
  def extract_urls_from_content(content)
    # Match URLs in text
    urls = content.scan(%r{https?://[^\s\)]+})

    # Also look for domain mentions
    domains = content.scan(/(?:https?:\/\/)?(?:www\.)?([a-z0-9-]+\.[a-z]{2,})/i)
                     .map { |match| match[0] }

    (urls + domains.map { |d| "https://#{d}" }).uniq
  end

  # Normalize domain to base URL
  def normalize_domain(url)
    uri = URI.parse(url)
    return nil unless uri.host

    # Remove www, return just domain
    host = uri.host.sub(/^www\./, "")
    "https://#{host}"
  rescue URI::InvalidURIError
    # Try to extract domain from string
    match = url.match(%r{(?:https?://)?(?:www\.)?([a-z0-9-]+\.[a-z]{2,})}i)
    match ? "https://#{match[1]}" : nil
  end

  # Calculate confidence score based on grounding metadata
  def calculate_keyword_confidence(metadata)
    # More sources = higher confidence
    sources = metadata[:sources_count]
    return 0.5 if sources == 0
    return 0.7 if sources <= 2
    return 0.85 if sources <= 5
    0.95
  end

  # Extract JSON from response that may be wrapped in markdown code blocks
  def extract_json_from_response(content)
    # Remove markdown code blocks if present
    if content.include?("```")
      # Extract content between ```json and ``` or ``` and ```
      json_match = content.match(/```(?:json)?\s*\n?(.*?)\n?```/m)
      return json_match[1].strip if json_match
    end

    # Try to find JSON object or array in the content
    if content =~ /^\s*[\[{]/
      # Content starts with [ or { - likely pure JSON
      return content.strip
    end

    # Look for JSON anywhere in the content
    json_match = content.match(/(\[.*\]|\{.*\})/m)
    return json_match[1] if json_match

    # Return content as-is and let JSON.parse fail with helpful error
    content.strip
  end
end
