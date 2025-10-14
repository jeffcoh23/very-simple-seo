# app/services/article_outline_service.rb
# Generates a structured JSON outline for an SEO article based on SERP research
class ArticleOutlineService
  def initialize(keyword, serp_data, voice_profile: nil, target_word_count: nil)
    @keyword = keyword
    @serp_data = serp_data
    @voice_profile = voice_profile
    @target_word_count = target_word_count
  end

  def perform
    Rails.logger.info "Generating outline for: #{@keyword}"

    outline = generate_outline

    if outline.nil?
      Rails.logger.error "Outline generation failed"
      return { data: nil, cost: 0.01 }
    end

    Rails.logger.info "Outline generated: #{outline['sections']&.size || 0} sections, #{outline['target_word_count']} words"

    { data: outline, cost: 0.01 } # Gemini 2.5 Flash is very cheap
  end

  private

  def generate_outline
    common_topics = @serp_data['common_topics']&.join(', ') || 'general information'
    content_gaps = @serp_data['content_gaps']&.join(', ') || 'unique insights'
    avg_word_count = @serp_data['average_word_count'] || 2000

    # Use user-provided target_word_count, or calculate based on competitors
    target_word_count = @target_word_count || [avg_word_count * 1.2, 2000].max.to_i

    # Get example companies and stats from SERP data
    examples = @serp_data['detailed_examples'] || []
    statistics = @serp_data['statistics'] || []

    examples_preview = examples.take(5).map { |ex|
      "- #{ex['company']}: #{ex['what_they_did']} → #{ex['outcome']}"
    }.join("\n")

    stats_preview = statistics.take(5).map { |stat|
      "- #{stat['stat']} (#{stat['source']})"
    }.join("\n")

    prompt = <<~PROMPT
      You are an expert SEO content strategist creating article outlines.

      TARGET KEYWORD: "#{@keyword}"

      COMPETITIVE ANALYSIS:
      - Common topics competitors cover: #{common_topics}
      - Content gaps to exploit: #{content_gaps}
      - Average competitor word count: #{avg_word_count} words
      - Your target: #{target_word_count} words (beat them by 20%)

      AVAILABLE REAL EXAMPLES:
      #{examples_preview.presence || "No examples available"}

      AVAILABLE STATISTICS:
      #{stats_preview.presence || "No statistics available"}

      #{voice_profile_instructions}

      Create a comprehensive, SEO-optimized outline that:
      1. Covers all common topics (to be competitive)
      2. Exploits content gaps (to rank better)
      3. Uses real examples and statistics provided above
      4. Targets #{target_word_count} words total
      5. Has 6-10 main sections (H2 headings)
      6. Each section has 2-4 subsections (H3 headings)
      7. Includes strategic tool placements where interactive elements would add value

      TOOL PLACEMENT GUIDELINES:
      - Calculator: for financial/ROI calculations
      - Checklist: for step-by-step processes
      - Quiz: for self-assessment or knowledge checks
      - Comparison: for comparing options/tools
      - Only include tools that genuinely add value

      Format your response as JSON:
      {
        "title": "SEO-optimized title with keyword (50-60 chars)",
        "meta_description": "Compelling meta description with keyword (150-160 chars)",
        "target_word_count": #{target_word_count},
        "sections": [
          {
            "heading": "Section heading (H2)",
            "word_count": 400,
            "key_points": ["point 1", "point 2", "point 3"],
            "subsections": [
              {
                "heading": "Subsection heading (H3)",
                "word_count": 200,
                "key_points": ["specific point 1", "specific point 2"]
              }
            ]
          }
        ],
        "tool_placements": [
          {
            "type": "calculator",
            "title": "ROI Calculator",
            "placement": "after_section_2",
            "purpose": "Help readers calculate their potential ROI"
          }
        ]
      }

      IMPORTANT:
      - Make the outline comprehensive enough to reach #{target_word_count} words
      - Include an Introduction section (200-300 words)
      - Include a Conclusion section (200-300 words)
      - Distribute word count evenly across sections
      - Use specific, actionable section headings
      - Reference the real examples and stats provided above in your key_points
    PROMPT

    client = Ai::ClientService.for_outline_generation
    response = client.chat(
      messages: [{ role: "user", content: prompt }],
      max_tokens: 8000, # Increased from 4000 to handle larger outlines
      temperature: 0.7
    )

    return nil unless response[:success]

    json_str = extract_json(response[:content])
    if json_str.nil?
      Rails.logger.error "No JSON found in response"
      return nil
    end

    outline = JSON.parse(json_str)

    # Validate outline structure
    unless outline['sections'].is_a?(Array) && outline['sections'].size >= 4
      Rails.logger.error "Invalid outline: insufficient sections"
      return nil
    end

    outline
  rescue JSON::ParserError => e
    Rails.logger.error "Failed to parse outline JSON: #{e.message}"
    Rails.logger.error "JSON string (first 500 chars): #{json_str[0..500]}" if json_str
    Rails.logger.error "AI Response (first 1000 chars): #{response[:content][0..1000]}" if response
    nil
  rescue => e
    Rails.logger.error "Outline generation error: #{e.message}"
    Rails.logger.error e.backtrace.first(3).join("\n")
    nil
  end

  def voice_profile_instructions
    return "" unless @voice_profile.present?

    <<~VOICE
      VOICE PROFILE:
      The article should match this writing style:
      #{@voice_profile}

      Ensure section headings and key points reflect this voice.
    VOICE
  end

  def extract_json(response)
    # Extract JSON from AI response (might be wrapped in markdown)
    if response.include?("```json")
      json = response[/```json\s*(.+?)\s*```/m, 1]
      json = response[/```json\s*(.+)/m, 1] if json.nil?
      json
    elsif response.include?("```")
      json = response[/```\s*(.+?)\s*```/m, 1]
      json = response[/```\s*(.+)/m, 1] if json.nil?
      json
    elsif response.include?("{")
      response[/(\{.+\})/m, 1]
    else
      response
    end
  end
end
