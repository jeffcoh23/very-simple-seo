# app/services/keyword_relevance_filter.rb
# Filters keywords by relevance to project's domain using AI
class KeywordRelevanceFilter
  def initialize(project)
    @project = project
    @domain_context = build_domain_context
  end

  # Filter a batch of keywords for relevance
  # Processes in batches to avoid token limits
  # Returns hash of { keyword => confidence_level }
  def filter_with_confidence(keywords)
    return {} if keywords.empty?

    Rails.logger.info "Filtering #{keywords.size} keywords for relevance..."

    # Process in batches of 200 keywords at a time to avoid token limits
    batch_size = 200
    all_keywords_with_confidence = {}

    keywords.each_slice(batch_size).with_index do |keyword_batch, index|
      Rails.logger.info "  Processing batch #{index + 1} (#{keyword_batch.size} keywords)..."

      # Build prompt with domain context and keywords to filter
      prompt = build_filter_prompt(keyword_batch)

      client = Ai::ClientService.for_keyword_analysis
      response = client.chat(
        messages: [{ role: "user", content: prompt }],
        system_prompt: "You are an expert at determining keyword relevance for SEO content strategy.",
        max_tokens: 2000,
        temperature: 0.2  # Low temperature for consistent filtering
      )

      unless response[:success]
        Rails.logger.warn "AI filtering failed for batch #{index + 1}, assuming medium confidence for all"
        keyword_batch.each { |kw| all_keywords_with_confidence[kw] = "medium" }
        next
      end

      # Parse the response to get keywords with confidence levels
      batch_results = parse_keywords_with_confidence(response[:content], keyword_batch)
      all_keywords_with_confidence.merge!(batch_results)

      high_count = batch_results.count { |_, conf| conf == "high" }
      medium_count = batch_results.count { |_, conf| conf == "medium" }
      low_count = batch_results.count { |_, conf| conf == "low" }

      Rails.logger.info "  Batch #{index + 1}: #{high_count} high, #{medium_count} medium, #{low_count} low confidence"
    end

    Rails.logger.info "Filter results: #{all_keywords_with_confidence.count { |_, c| c == 'high' }} high, #{all_keywords_with_confidence.count { |_, c| c == 'medium' }} medium, #{all_keywords_with_confidence.count { |_, c| c == 'low' }} low"
    all_keywords_with_confidence
  end

  # Legacy method for backward compatibility
  # Returns array of keywords (high + medium confidence)
  def filter(keywords)
    results = filter_with_confidence(keywords)
    results.select { |_, conf| conf == "high" || conf == "medium" }.keys
  end

  private

  def build_domain_context
    domain_analysis = @project.domain_analysis || {}

    {
      domain: @project.domain,
      name: @project.name,
      niche: @project.niche,
      description: @project.description,
      title: domain_analysis[:title],
      h1s: domain_analysis[:h1s]&.first(3)&.join(", "),
      h2s: domain_analysis[:h2s]&.first(5)&.join(", ")
    }
  end

  def build_filter_prompt(keywords)
    keywords_list = keywords.map.with_index { |kw, i| "#{i + 1}. #{kw}" }.join("\n")

    <<~PROMPT
      I need to filter keywords for relevance to this website using a THREE-TIER confidence system:

      DOMAIN: #{@domain_context[:domain]}
      NAME: #{@domain_context[:name]}
      NICHE: #{@domain_context[:niche]}
      DESCRIPTION: #{@domain_context[:description]}
      PAGE TITLE: #{@domain_context[:title]}
      MAIN TOPICS (H1s): #{@domain_context[:h1s]}
      CONTENT TOPICS (H2s): #{@domain_context[:h2s]}

      KEYWORDS TO FILTER:
      #{keywords_list}

      YOUR TASK:
      Classify each keyword into one of three confidence levels:

      🟢 HIGH CONFIDENCE - Core keywords that directly match what this site does:
      - Keywords that describe the EXACT solution/service offered
      - Keywords matching the MAIN problems the site solves (based on H1s, title, description)
      - Keywords about the core PROCESS/METHODOLOGY provided
      - Users searching these terms are CLEARLY the target audience

      🟡 MEDIUM CONFIDENCE - Adjacent topics that relate to the customer journey:
      - Keywords from one step BEFORE or AFTER the core solution
      - Related topics that the target persona might also search for
      - Tangentially related but could write authentic content with natural product bridge
      - Same persona, slightly different need

      🔴 LOW CONFIDENCE - Remove these:
      - Generic industry terms with no connection to specific solution
      - Keywords targeting completely different personas
      - Different service categories or trade types
      - Different stage of journey with no logical connection
      - Topics where content bridge would feel forced

      EVALUATION QUESTIONS (ask for each keyword):
      1. Does this target the SAME PERSON who would use this site?
      2. Is this part of the PROBLEM/SOLUTION JOURNEY this site addresses?
      3. Could you write AUTHENTIC content that naturally bridges to this site's offering?

      - YES to all 3 → HIGH confidence
      - YES to 2 → MEDIUM confidence
      - YES to ≤1 → LOW confidence

      Return ONLY a JSON object mapping keyword numbers to confidence levels:
      {
        "high": ["1", "5", "12"],
        "medium": ["3", "7", "19"],
        "low": ["2", "4", "8"]
      }

      Be thoughtful but not overly strict. High = 30-40%, Medium = 20-30%, Low = 30-50%.
    PROMPT
  end

  def parse_keywords_with_confidence(response, original_keywords)
    # Extract JSON object from response
    json_str = response[/\{.*?\}/m]

    # Fallback: assume medium confidence for all
    unless json_str
      return original_keywords.each_with_object({}) { |kw, hash| hash[kw] = "medium" }
    end

    begin
      confidence_tiers = JSON.parse(json_str)

      # Get indices for each confidence level
      high_indices = (confidence_tiers["high"] || []).map(&:to_i)
      medium_indices = (confidence_tiers["medium"] || []).map(&:to_i)
      low_indices = (confidence_tiers["low"] || []).map(&:to_i)

      # Map keywords to their confidence levels
      keyword_confidence = {}

      high_indices.each do |idx|
        kw = original_keywords[idx - 1]
        keyword_confidence[kw] = "high" if kw
      end

      medium_indices.each do |idx|
        kw = original_keywords[idx - 1]
        keyword_confidence[kw] = "medium" if kw
      end

      low_indices.each do |idx|
        kw = original_keywords[idx - 1]
        keyword_confidence[kw] = "low" if kw
      end

      # If AI didn't classify some keywords, assume medium confidence
      original_keywords.each do |kw|
        keyword_confidence[kw] ||= "medium"
      end

      keyword_confidence
    rescue JSON::ParserError => e
      Rails.logger.error "Failed to parse relevance filter response: #{e.message}"
      Rails.logger.error "Response was: #{response}"
      # Fallback: medium confidence for all
      original_keywords.each_with_object({}) { |kw, hash| hash[kw] = "medium" }
    end
  end

  # Legacy parsing method for backward compatibility
  def parse_relevant_keywords(response, original_keywords)
    results = parse_keywords_with_confidence(response, original_keywords)
    results.select { |_, conf| conf == "high" || conf == "medium" }.keys
  end
end
