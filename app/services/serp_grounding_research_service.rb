# app/services/serp_grounding_research_service.rb
# Replaces SerpResearchService with Google Grounding API
# FOCUSED: Rich resources only (stats, videos, downloads, real tools)
# NO generic analysis, NO AI-generated guides

class SerpGroundingResearchService
  def initialize(keyword, project: nil)
    @keyword = keyword
    @project = project
  end

  def perform
    Rails.logger.info "Starting Grounding research for: #{@keyword}"

    # Make 3 focused resource-gathering calls
    stats_data = fetch_statistics_and_data
    resources_data = fetch_rich_resources
    faqs_data = fetch_faqs

    # Merge all results
    serp_data = merge_research_data(stats_data, resources_data, faqs_data)

    # Validate and clean results
    serp_data = validate_and_clean_results(serp_data)

    Rails.logger.info "Grounding research complete:"
    Rails.logger.info "  - Statistics: #{serp_data['statistics']&.size || 0}"
    Rails.logger.info "  - Videos: #{serp_data['visual_elements']['videos']&.size || 0}"
    Rails.logger.info "  - Downloadable resources: #{serp_data['downloadable_resources']['resources']&.size || 0}"
    Rails.logger.info "  - Tools: #{serp_data['recommended_tools']&.size || 0}"
    Rails.logger.info "  - FAQs: #{serp_data['faqs']&.size || 0}"

    { data: serp_data, cost: 0.15 } # 3 API calls
  end

  private

  # Call #1: Statistics and hard data ONLY
  def fetch_statistics_and_data
    prompt = <<~PROMPT
      Search the web for 15-20 CURRENT, AUTHORITATIVE statistics about "#{@keyword}".

      For EACH statistic, you MUST include:
      - stat: The exact statistic with number
      - source: Organization/company name
      - source_url: Direct link to research (REQUIRED - no blank URLs)
      - year: Publication year (REQUIRED)
      - context: Why this matters (1 sentence)

      CRITICAL REQUIREMENTS:
      - Every stat MUST have a valid source_url (no empty strings)
      - Prioritize recent data (last 2-3 years)
      - Include authoritative sources (research firms, industry reports, academic studies)
      - NO made-up statistics
      - NO duplicate statistics (each must be unique)

      Return ONLY valid JSON array:
      [
        {
          "stat": "42% of startups fail due to no market need",
          "source": "CB Insights",
          "source_url": "https://www.cbinsights.com/research/startup-failure-reasons-top/",
          "year": "2023",
          "context": "Primary reason for startup failure across 100+ post-mortems"
        }
      ]
    PROMPT

    call_grounding_api(prompt, "statistics")
  end

  # Call #2: Rich multimedia resources (videos, downloads, tools)
  def fetch_rich_resources
    prompt = <<~PROMPT
      Search the web for RICH MULTIMEDIA RESOURCES about "#{@keyword}".

      ## 1. YOUTUBE VIDEOS (Find 3-5 high-quality tutorial/educational videos)
      For EACH video:
      - url: YouTube URL
      - title: Video title
      - channel: Channel name
      - description: What it teaches (1-2 sentences)
      - duration: Video length if available
      - views: View count if available

      ONLY include educational/tutorial videos, NOT marketing or ads.

      ## 2. DOWNLOADABLE RESOURCES (Find 5-8 free templates, tools, checklists)
      For EACH resource:
      - title: Resource name
      - type: "template", "ebook", "checklist", "calculator", "worksheet", etc.
      - url: Direct download/access URL
      - description: What it provides (1-2 sentences)
      - provider: Who created it (company/org name)

      ONLY include FREE resources that users can actually download/access.

      ## 3. RECOMMENDED TOOLS (Find 5-8 software tools mentioned for this topic)
      For EACH tool:
      - tool_name: Name of the tool
      - category: What type of tool (e.g., "Survey Tool", "Analytics Platform")
      - use_case: How it's specifically used for this topic (1-2 sentences)
      - pricing: Pricing summary (e.g., "Free tier available, paid from $25/mo")
      - url: Tool website URL
      - why_recommended: 1 sentence on why it's useful for this use case

      ONLY include tools that are actually mentioned in web results, NOT generic suggestions.

      CRITICAL REQUIREMENTS:
      - All URLs must be valid and accessible
      - Focus on HIGH-QUALITY resources only (popular videos, reputable providers)
      - NO generic AI-generated suggestions - only REAL resources found on the web
      - Prioritize variety (mix of videos, templates, tools)

      Return ONLY valid JSON object:
      {
        "videos": [
          {
            "url": "https://youtube.com/watch?v=...",
            "title": "How to Validate Your Startup Idea in 30 Days",
            "channel": "Y Combinator",
            "description": "YC partners walk through their validation framework with real examples",
            "duration": "15:43",
            "views": "234K"
          }
        ],
        "downloadable_resources": [
          {
            "title": "Customer Interview Script Template",
            "type": "google_doc",
            "url": "https://docs.google.com/...",
            "description": "15-question interview script with follow-up prompts",
            "provider": "First Round Review"
          }
        ],
        "recommended_tools": [
          {
            "tool_name": "Typeform",
            "category": "Survey Tool",
            "use_case": "Create professional customer validation surveys with conditional logic",
            "pricing": "Free tier available, paid from $25/mo",
            "url": "https://typeform.com",
            "why_recommended": "Easiest way to collect structured feedback from potential customers"
          }
        ]
      }
    PROMPT

    call_grounding_api(prompt, "rich_resources")
  end

  # Call #3: Real FAQs from web
  def fetch_faqs
    prompt = <<~PROMPT
      Search the web for 10-15 REAL questions people ask about "#{@keyword}".

      Sources to check:
      - Google's "People Also Ask" boxes
      - Reddit discussions
      - Quora threads
      - Forum posts
      - Comment sections on popular articles

      For EACH question:
      - question: The exact question (as users ask it)
      - answer: Comprehensive answer (3-5 sentences)
      - source_url: URL where you found this question/answer (if available)

      CRITICAL REQUIREMENTS:
      - Questions must be REAL (not AI-generated)
      - Answers should be authoritative and complete
      - Prioritize questions that appear in multiple places (common pain points)
      - NO generic FAQs - find what people ACTUALLY ask

      Return ONLY valid JSON array:
      [
        {
          "question": "How many customer interviews do I need to validate my idea?",
          "answer": "Most experts recommend 15-25 customer interviews for B2B products and 30-50 for B2C products. This sample size helps identify patterns in pain points and willingness to pay. Stop when you're no longer hearing new information (saturation point).",
          "source_url": "https://..."
        }
      ]
    PROMPT

    call_grounding_api(prompt, "faqs")
  end

  def call_grounding_api(prompt, request_type)
    Rails.logger.info "Grounding API call: #{request_type}"

    begin
      # Call Gemini with google_search tool
      chat = RubyLLM.chat(provider: :gemini, model: "gemini-2.5-pro")
                    .with_temperature(0.3)
                    .with_params(
                      tools: [ { google_search: {} } ],
                      generationConfig: {
                        maxOutputTokens: 8000
                      }
                    )

      response = chat.ask(prompt)
      content = response.content.strip

      # Extract JSON from response
      json_content = extract_json_from_response(content)

      # Parse JSON response
      data = JSON.parse(json_content)

      Rails.logger.info "#{request_type} returned: #{data.is_a?(Array) ? data.size : data.keys.size} items"
      data

    rescue JSON::ParserError => e
      Rails.logger.error "JSON parse error for #{request_type}: #{e.message}"
      Rails.logger.error "Content: #{content[0..500]}" if content
      request_type == "rich_resources" ? {} : []
    rescue => e
      Rails.logger.error "Grounding API error for #{request_type}: #{e.message}"
      Rails.logger.error e.backtrace.first(3).join("\n")
      request_type == "rich_resources" ? {} : []
    end
  end

  def merge_research_data(stats, resources, faqs)
    {
      # Statistics
      "statistics" => stats || [],

      # Rich multimedia resources
      "visual_elements" => {
        "images" => [], # Removed - causing broken links
        "videos" => resources["videos"] || []
      },
      "downloadable_resources" => {
        "resources" => resources["downloadable_resources"] || []
      },
      "recommended_tools" => resources["recommended_tools"] || [],

      # FAQs
      "faqs" => faqs || [],

      # Empty placeholders (for backward compatibility)
      "detailed_examples" => [],
      "step_by_step_guides" => { "guides" => [] },
      "comparison_tables" => { "tables" => [] },
      "internal_link_opportunities" => [],
      "cta_placements" => [],
      "common_topics" => [],
      "content_gaps" => [],
      "average_word_count" => 2500,
      "recommended_approach" => ""
    }
  end

  def validate_and_clean_results(data)
    # Remove stats without valid source URLs
    if data["statistics"].is_a?(Array)
      data["statistics"] = data["statistics"]
        .uniq { |stat| stat["stat"] }
        .reject { |stat| stat["source_url"].blank? || stat["source_url"].empty? }
        .reject { |stat| stat["year"].blank? } # Require year
    end

    # Remove invalid videos
    if data["visual_elements"]["videos"].is_a?(Array)
      data["visual_elements"]["videos"] = data["visual_elements"]["videos"]
        .reject { |v| v["url"].blank? || !v["url"].include?("youtube.com") }
    end

    # Remove invalid downloadable resources
    if data["downloadable_resources"]["resources"].is_a?(Array)
      data["downloadable_resources"]["resources"] = data["downloadable_resources"]["resources"]
        .reject { |r| r["url"].blank? || r["title"].blank? }
    end

    # Remove empty tools
    if data["recommended_tools"].is_a?(Array)
      data["recommended_tools"] = data["recommended_tools"]
        .reject { |tool| tool["tool_name"].blank? || tool["url"].blank? }
    end

    Rails.logger.info "After validation:"
    Rails.logger.info "  - Statistics: #{data['statistics']&.size} (removed blank URLs and missing years)"
    Rails.logger.info "  - Videos: #{data['visual_elements']['videos']&.size} (YouTube only)"
    Rails.logger.info "  - Downloads: #{data['downloadable_resources']['resources']&.size}"
    Rails.logger.info "  - Tools: #{data['recommended_tools']&.size}"

    data
  end

  def extract_json_from_response(content)
    # Remove markdown code blocks if present
    if content.include?("```")
      json_match = content.match(/```(?:json)?\s*\n?(.*?)\n?```/m)
      return json_match[1].strip if json_match
    end

    # Try to find JSON object or array
    if content =~ /^\s*[\[{]/
      return content.strip
    end

    # Look for JSON anywhere in the content
    json_match = content.match(/(\[.*\]|\{.*\})/m)
    return json_match[1] if json_match

    content.strip
  end
end
