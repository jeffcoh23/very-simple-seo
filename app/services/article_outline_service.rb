# app/services/article_outline_service.rb
# Generates a structured JSON outline for an SEO article based on SERP research
class ArticleOutlineService
  def initialize(keyword, serp_data, voice_profile: nil, target_word_count: nil, project: nil)
    @keyword = keyword
    @serp_data = serp_data
    @voice_profile = voice_profile
    @target_word_count = target_word_count
    @project = project
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

    # NEW: Get FAQs, People Also Ask, and internal linking data
    faqs = @serp_data['faqs'] || []
    people_also_ask = @serp_data['people_also_ask'] || []
    internal_links = @serp_data['internal_link_opportunities'] || []
    cta_placements = @serp_data['cta_placements'] || []

    faqs_preview = faqs.take(5).map { |faq|
      "- Q: #{faq['question']}\n  A: #{faq['answer'][0..100]}..."
    }.join("\n")

    paa_preview = people_also_ask.take(3).map { |paa|
      "- #{paa['question']} (suggest as H2: #{paa['should_be_h2_section']})"
    }.join("\n")

    internal_links_preview = internal_links.take(3).map { |link|
      "- Link to: \"#{link['target_article_title']}\" (#{link['placement']})"
    }.join("\n")

    # NEW: Get project CTAs instead of hardcoded examples
    project_ctas = @project&.call_to_actions || []
    cta_preview = if project_ctas.any?
      project_ctas.take(3).map { |cta|
        "- \"#{cta['cta_text']}\" → #{cta['cta_url']} (Placement: #{cta['placement'] || 'flexible'})"
      }.join("\n")
    else
      "No CTAs configured - will use generic calls to action"
    end

    # NEW: Build brand context for natural integration
    brand_context = if @project
      <<~BRAND
      BRAND CONTEXT (integrate naturally into outline):
      - Product Name: #{@project.name}
      - Domain: #{@project.domain}
      - Position #{@project.name} as a tool/resource that helps with "#{@keyword}"
      - Include 2-3 natural brand mentions across the article (intro, methods section, conclusion)
      - Frame it as: "Tools like #{@project.name} can help by..." or "#{@project.name} simplifies [task] by..."
      - Don't force it - only mention where contextually relevant

      BRAND
    else
      ""
    end

    prompt = <<~PROMPT
      You are an expert SEO content strategist creating article outlines.

      TARGET KEYWORD: "#{@keyword}"

      #{brand_context}

      COMPETITIVE ANALYSIS:
      - Common topics competitors cover: #{common_topics}
      - Content gaps to exploit: #{content_gaps}
      - Average competitor word count: #{avg_word_count} words
      - Your target: #{target_word_count} words (beat them by 20%)

      AVAILABLE REAL EXAMPLES:
      #{examples_preview.presence || "No examples available"}

      AVAILABLE STATISTICS:
      #{stats_preview.presence || "No statistics available"}

      AVAILABLE FAQs (for FAQ section):
      #{faqs_preview.presence || "No FAQs available"}

      PEOPLE ALSO ASK (consider as H2 sections):
      #{paa_preview.presence || "No PAA questions available"}

      INTERNAL LINK OPPORTUNITIES (to existing articles):
      #{internal_links_preview.presence || "No internal links available"}

      CTA PLACEMENTS (project CTAs to include):
      #{cta_preview.presence || "No CTAs available"}

      #{voice_profile_instructions}

      Create a comprehensive, SEO-optimized outline that:
      1. Covers all common topics (to be competitive)
      2. Exploits content gaps (to rank better)
      3. Uses real examples and statistics provided above
      4. Targets #{target_word_count} words total
      5. Has 6-10 main sections (H2 headings)
      6. Each section has 2-4 subsections (H3 headings)
      7. Includes strategic tool placements where interactive elements would add value
      8. INCLUDES A DEDICATED FAQ SECTION (H2) near the end with 8-12 questions
      9. Plans internal link placements in relevant sections
      10. Plans CTA placements at strategic points (not all at once)

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
        "has_faq_section": true,
        "faq_section_index": 7,
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
            ],
            "internal_links": [
              {
                "anchor_text": "customer interview best practices",
                "target_article_title": "How to Conduct Interviews",
                "context": "Mention in subsection about validation methods"
              }
            ]
          }
        ],
        "faq_section": {
          "heading": "Frequently Asked Questions",
          "word_count": 600,
          "questions_to_include": [
            "How many customer interviews do I need?",
            "What's the difference between validation and research?"
          ]
        },
        "tool_placements": [
          {
            "type": "calculator",
            "title": "ROI Calculator",
            "placement": "after_section_2",
            "purpose": "Help readers calculate their potential ROI"
          }
        ],
        "cta_placements": #{project_ctas.any? ? project_ctas.to_json : '[]'}
      }

      IMPORTANT:
      - Make the outline comprehensive enough to reach #{target_word_count} words
      - Include an Introduction section (200-300 words)
      - Include a FAQ section near the end (before Conclusion)
      - Include a Conclusion section (200-300 words)
      - Distribute word count evenly across sections
      - Use specific, actionable section headings
      - Reference the real examples and stats provided above in your key_points
      - Plan internal link placements in sections where they're contextually relevant
      - Space out CTA placements (don't put them all in one place)
      - Consider People Also Ask questions as potential H2 section topics
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

    # Ensure has_faq_section is set (for backward compatibility with old outlines)
    outline['has_faq_section'] ||= outline.key?('faq_section')

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
