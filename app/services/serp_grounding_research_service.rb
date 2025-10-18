# app/services/serp_grounding_research_service.rb
# Replaces SerpResearchService with Google Grounding API
# Uses comprehensive web search instead of HTML scraping
# Includes: examples, stats, FAQs, tables, guides, videos, tools, internal links, CTAs

class SerpGroundingResearchService
  def initialize(keyword, project: nil)
    @keyword = keyword
    @project = project
  end

  def perform
    Rails.logger.info "Starting Grounding research for: #{@keyword}"

    # Build context about project's existing content
    internal_context = build_internal_context

    # Make 3 focused research calls instead of 1 overwhelming call
    examples_data = fetch_examples_and_case_studies
    stats_data = fetch_statistics_and_data
    content_data = fetch_content_elements(internal_context)

    # Merge all results
    serp_data = merge_research_data(examples_data, stats_data, content_data)

    # Validate and clean results
    serp_data = validate_and_clean_results(serp_data)

    Rails.logger.info "Grounding research complete:"
    Rails.logger.info "  - Examples: #{serp_data['detailed_examples']&.size || 0}"
    Rails.logger.info "  - Statistics: #{serp_data['statistics']&.size || 0}"
    Rails.logger.info "  - FAQs: #{serp_data['faqs']&.size || 0}"
    Rails.logger.info "  - Tools: #{serp_data['recommended_tools']&.size || 0}"

    { data: serp_data, cost: 0.15 } # 3 API calls instead of 1
  end

  private

  # Focused call #1: Real-world examples and case studies
  def fetch_examples_and_case_studies
    prompt = <<~PROMPT
      Search the web for 8-10 REAL examples of companies/people succeeding with "#{@keyword}".

      For EACH example, you MUST include:
      - company: Company or person name
      - what_they_did: The tactic/strategy (1-2 sentences)
      - how_they_did_it: SPECIFIC steps, tools, channels (3-4 sentences with HOW details)
      - timeline: When they did it (year, duration)
      - outcome: Quantified results (numbers, metrics)
      - source_url: EXACT URL where you found this (REQUIRED)

      CRITICAL REQUIREMENTS:
      - Include tactical HOW details (tools, platforms, exact steps)
      - Every example MUST have a source_url
      - Use INLINE CITATIONS [1], [2], [3] for each fact
      - NO placeholder/generic examples
      - Focus on verified, recent examples (last 5 years)

      Return ONLY valid JSON array:
      [
        {
          "company": "Dropbox",
          "what_they_did": "Validated demand before building product",
          "how_they_did_it": "Created 3-minute demo video showing product concept, posted on Hacker News with email signup form, drove traffic through targeted tech community outreach",
          "timeline": "2008, 4 months before first beta release",
          "outcome": "75,000 beta signups, 15% conversion to paid tier at launch",
          "source_url": "https://techcrunch.com/2011/10/19/dropbox-minimal-viable-product/"
        }
      ]
    PROMPT

    call_grounding_api(prompt, "examples")
  end

  # Focused call #2: Statistics and hard data
  def fetch_statistics_and_data
    prompt = <<~PROMPT
      Search the web for 12-15 CURRENT, AUTHORITATIVE statistics about "#{@keyword}".

      For EACH statistic, you MUST include:
      - stat: The exact statistic with number
      - source: Organization/company name
      - source_url: Direct link to research (REQUIRED)
      - year: Publication year
      - context: Why this matters (1 sentence)

      CRITICAL REQUIREMENTS:
      - Use INLINE CITATIONS [1], [2], [3] for each stat
      - Every stat MUST have source_url
      - Prioritize recent data (last 2-3 years)
      - Include authoritative sources (research firms, industry reports)
      - NO made-up statistics

      Return ONLY valid JSON array:
      [
        {
          "stat": "42% of startups fail due to no market need",
          "source": "CB Insights",
          "source_url": "https://www.cbinsights.com/research/startup-failure-post-mortem/",
          "year": "2023",
          "context": "Primary reason for startup failure across 100+ post-mortems"
        }
      ]
    PROMPT

    call_grounding_api(prompt, "statistics")
  end

  # Focused call #3: Content elements (FAQs, tools, guides)
  def fetch_content_elements(internal_context)
    internal_section = internal_context ? build_internal_linking_prompt(internal_context) : ""

    prompt = <<~PROMPT
      Search the web for content elements related to "#{@keyword}".

      ## 1. FREQUENTLY ASKED QUESTIONS (8-10 questions)
      Find real questions people ask. For each:
      - question: Exact question
      - answer: Comprehensive answer (3-5 sentences)
      - source_url: URL if answer contains specific claims

      ## 2. RECOMMENDED TOOLS (6-8 tools)
      Find specific tools mentioned for this topic. For each:
      - tool_name: Name
      - category: Type of tool
      - use_case: How it's used
      - pricing: Tier summary
      - url: Tool website
      - why_recommended: 1 sentence

      ## 3. STEP-BY-STEP GUIDES (3-5 guides)
      Find actionable frameworks. For each:
      - title: Guide title
      - steps: Specific actions (array of 5-8 steps)
      - outcome: Expected result
      - source_url: Where found

      ## 4. COMPARISON TABLES (2-3 tables)
      Create or find comparison tables. For each:
      - title: Table title
      - headers: Column names
      - rows: Data rows
      - source_url: Data source

      #{internal_section}

      CRITICAL REQUIREMENTS:
      - Use INLINE CITATIONS [1], [2], [3] for all facts
      - Every item with facts MUST have source_url
      - Focus on practical, actionable content
      - NO generic advice

      Return ONLY valid JSON object with these keys:
      {
        "faqs": [...],
        "recommended_tools": [...],
        "step_by_step_guides": [...],
        "comparison_tables": [...],
        "internal_link_opportunities": [...],
        "cta_placements": [...]
      }
    PROMPT

    call_grounding_api(prompt, "content_elements")
  end

  def call_grounding_api(prompt, request_type)
    Rails.logger.info "Grounding API call: #{request_type}"

    begin
      # Call Gemini with google_search tool
      # Note: Can't use responseMimeType with tools, so we rely on prompt formatting
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

      # Extract JSON from response (may have markdown code blocks or text around it)
      json_content = extract_json_from_response(content)

      # Parse JSON response
      data = JSON.parse(json_content)

      Rails.logger.info "#{request_type} returned: #{data.is_a?(Array) ? data.size : 'object'} items"
      data

    rescue JSON::ParserError => e
      Rails.logger.error "JSON parse error for #{request_type}: #{e.message}"
      Rails.logger.error "Content: #{content[0..500]}" if content
      request_type == "content_elements" ? {} : []
    rescue => e
      Rails.logger.error "Grounding API error for #{request_type}: #{e.message}"
      Rails.logger.error e.backtrace.first(3).join("\n")
      request_type == "content_elements" ? {} : []
    end
  end

  def merge_research_data(examples, stats, content)
    {
      "detailed_examples" => examples || [],
      "statistics" => stats || [],
      "faqs" => content["faqs"] || [],
      "recommended_tools" => content["recommended_tools"] || [],
      "step_by_step_guides" => { "guides" => content["step_by_step_guides"] || [] },
      "comparison_tables" => { "tables" => content["comparison_tables"] || [] },
      "internal_link_opportunities" => content["internal_link_opportunities"] || [],
      "cta_placements" => content["cta_placements"] || [],
      "visual_elements" => { "images" => [], "videos" => [] }, # Will add later
      "downloadable_resources" => { "resources" => [] },
      "common_topics" => [],
      "content_gaps" => [],
      "average_word_count" => 2500,
      "recommended_approach" => ""
    }
  end

  def validate_and_clean_results(data)
    # Remove duplicates from examples
    if data["detailed_examples"].is_a?(Array)
      data["detailed_examples"] = data["detailed_examples"]
        .uniq { |ex| ex["company"]&.downcase }
        .reject { |ex| ex["company"].blank? || ex["outcome"].blank? || ex["source_url"].blank? }
    end

    # Remove stats without sources
    if data["statistics"].is_a?(Array)
      data["statistics"] = data["statistics"]
        .uniq { |stat| stat["stat"] }
        .reject { |stat| stat["source_url"].blank? }
    end

    # Remove empty tools
    if data["recommended_tools"].is_a?(Array)
      data["recommended_tools"] = data["recommended_tools"]
        .reject { |tool| tool["tool_name"].blank? || tool["url"].blank? }
    end

    Rails.logger.info "After validation:"
    Rails.logger.info "  - Examples: #{data['detailed_examples']&.size} (duplicates removed)"
    Rails.logger.info "  - Statistics: #{data['statistics']&.size} (no-source removed)"
    Rails.logger.info "  - Tools: #{data['recommended_tools']&.size} (empty removed)"

    data
  end

  def extract_json_from_response(content)
    # Remove markdown code blocks if present
    if content.include?("```")
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

  def build_internal_context
    return nil unless @project

    link_suggester = InternalLinkSuggester.new(@project)
    link_suggester.build_internal_linking_context
  end

  def build_comprehensive_research_prompt(internal_context)
    internal_linking_section = build_internal_linking_prompt(internal_context)

    <<~PROMPT
      You are an expert SEO content researcher. Perform comprehensive web research on "#{@keyword}" and gather ALL of the following elements:

      ## 1. REAL-WORLD EXAMPLES & CASE STUDIES
      Find 10-15 real examples of companies/people succeeding with this topic.
      For EACH example, you MUST include:
      - company: Company or person name
      - what_they_did: The tactic/strategy (1-2 sentences)
      - how_they_did_it: SPECIFIC steps, tools, channels used (2-3 sentences with tactical details)
      - timeline: When they did it (year, duration, timeframe)
      - outcome: Quantified results (numbers, percentages, growth metrics)
      - source_url: Direct URL where you found this information

      CRITICAL: Include HOW details (tools, platforms, exact steps), not just WHAT and OUTCOME.
      Example: "Posted 3-minute demo video on Hacker News with email signup, before writing any code"

      ## 2. STATISTICS & DATA
      Find 15-20 current, authoritative statistics.
      For EACH statistic:
      - stat: The exact statistic with number
      - source: Organization/company name
      - source_url: Direct link to research/article
      - year: When the stat was published
      - context: Why this stat matters (1 sentence)

      Prioritize recent statistics (last 2 years).

      ## 3. FREQUENTLY ASKED QUESTIONS (FAQs)
      Find 10-15 questions people actually ask about this topic.
      For EACH question:
      - question: The exact question (as users ask it)
      - answer: Comprehensive answer (3-5 sentences)
      - source_url: URL if answer contains specific claims

      Use "People Also Ask", forums, Reddit, Quora to find real questions.
      These will be used for FAQ schema markup and featured snippets.

      ## 4. PEOPLE ALSO ASK (Related Questions)
      Find 5-10 questions from Google's "People Also Ask" boxes.
      For EACH question:
      - question: The exact question from PAA
      - brief_answer: 2-3 sentence answer
      - should_be_h2_section: true/false (recommend making this a section heading)
      - related_keywords: Array of keyword variations for this question

      These are GOLD for SEO - they can trigger featured snippets.

      ## 5. COMPARISON TABLES
      Find 3-5 comparison tables or create them from research.
      For EACH table:
      - title: Clear table title
      - headers: Column names (array)
      - rows: Data rows (array of arrays)
      - source_url: Where you found this data

      Examples: "X vs Y features", "Pricing comparison", "Method effectiveness"

      ## 6. STEP-BY-STEP GUIDES
      Find 3-5 actionable frameworks or processes.
      For EACH guide:
      - title: Clear guide title
      - steps: Specific actions (array of 3-10 steps with HOW details)
      - outcome: Expected result
      - source_url: Where you found this guide

      Avoid generic advice. Include tools, timelines, exact actions.

      ## 7. VISUAL ELEMENTS
      Find 3-5 relevant images/diagrams AND 1-2 tutorial videos.
      For EACH visual:
      - url: Image/video URL
      - type: "image" or "video"
      - platform: "youtube", "vimeo", or "image"
      - description: What it shows
      - embed_recommended: true/false (only true for highly relevant videos)
      - source_url: Article where it appears

      For videos: Prefer tutorials over marketing videos.
      For images: Ignore stock photos, headshots, logos.

      ## 8. DOWNLOADABLE RESOURCES
      Find 3-5 free templates, tools, calculators.
      For EACH resource:
      - title: Resource name
      - type: "template", "checklist", "calculator", etc.
      - url: Direct download/access URL
      - description: What it provides

      ## 9. RECOMMENDED TOOLS
      Find 5-8 specific tools mentioned for this topic.
      For EACH tool:
      - tool_name: Name of the tool
      - category: What type of tool (e.g., "Survey Tool", "Analytics")
      - use_case: How it's used for this topic
      - pricing: Pricing tier summary (e.g., "Free tier available, paid from $25/mo")
      - url: Tool website
      - why_recommended: 1 sentence on why it's good for this use case

      #{internal_linking_section}

      ## 11. COMPETITIVE ANALYSIS
      Analyze top 5-10 ranking articles.
      Summary:
      - common_topics: Topics that appear in multiple articles (array)
      - content_gaps: Topics missing from current content (array)
      - average_word_count: Average length of top articles (integer)
      - recommended_approach: How to beat current results (2-3 sentences)

      ## CRITICAL REQUIREMENTS:
      - Every fact MUST have a source_url
      - Prioritize recent, authoritative sources
      - Be comprehensive - gather as much as possible
      - Focus on tactical HOW details, not fluffy advice
      - Use real data from web search, don't make anything up

      Search the web thoroughly and return ALL findings in the JSON structure provided.
    PROMPT
  end

  def build_internal_linking_prompt(internal_context)
    return "" unless internal_context && internal_context["existing_articles"]&.any?

    existing_articles = internal_context["existing_articles"]
    ctas = internal_context["ctas"] || []

    <<~SECTION
      ## 10. INTERNAL LINKING & CTAs

      This project has existing content. Suggest internal links and CTA placements.

      EXISTING ARTICLES ON THIS SITE:
      #{existing_articles.map { |a| "- \"#{a['title']}\" (keyword: #{a['keyword']}) - Topics: #{a['topics']&.join(', ')}" }.join("\n")}

      PROJECT CTAs (calls-to-action):
      #{ctas.map { |c| "- \"#{c['text']}\" → #{c['url']} (context: #{c['context']})" }.join("\n")}

      For internal_link_opportunities, suggest 3-5 places to link to existing articles:
      - anchor_text: Natural anchor text for the link
      - target_article_title: Which existing article to link to
      - placement: "in_introduction", "in_section_2", "in_section_3", etc.
      - relevance_reason: Why this link makes sense (1 sentence)

      For cta_placements, suggest 1-2 places to include CTAs:
      - cta_text: The CTA text from the project
      - cta_url: The CTA URL
      - placement: Where to place it ("end_of_section_3", "in_conclusion", etc.)
      - context: Why this CTA fits here (1 sentence)

      #{internal_context['linking_guidelines']}
    SECTION
  end

  def build_json_structure_hint
    <<~JSON
      {
        "examples": [
          {
            "company": "Dropbox",
            "what_they_did": "Validated demand with demo video before building product",
            "how_they_did_it": "Created 3-minute explainer video showing product concept, posted on Hacker News with waitlist signup link, no code written yet",
            "timeline": "2008, 6 months before first beta",
            "outcome": "75,000 signups overnight, 15% conversion to paid beta",
            "source_url": "https://..."
          }
        ],
        "statistics": [
          {
            "stat": "42% of startups fail due to no market need",
            "source": "CB Insights",
            "source_url": "https://www.cbinsights.com/research/...",
            "year": "2023",
            "context": "Top reason for startup failure across 101 post-mortems"
          }
        ],
        "faqs": [
          {
            "question": "How many customer interviews do I need to validate my idea?",
            "answer": "Most experts recommend 15-25 customer interviews for B2B products and 30-50 for B2C. This sample size helps identify patterns in pain points and willingness to pay.",
            "source_url": "https://..."
          }
        ],
        "people_also_ask": [
          {
            "question": "What's the difference between idea validation and market research?",
            "brief_answer": "Idea validation tests a specific solution before building, while market research analyzes broader market trends.",
            "should_be_h2_section": true,
            "related_keywords": ["idea validation vs market research"]
          }
        ],
        "comparison_tables": [
          {
            "title": "Validation Methods: Speed vs. Accuracy",
            "headers": ["Method", "Time", "Accuracy", "Cost"],
            "rows": [
              ["Landing Page", "1-2 weeks", "Medium", "$50-200"],
              ["Customer Interviews", "2-4 weeks", "High", "$0-500"]
            ],
            "source_url": "https://..."
          }
        ],
        "step_by_step_guides": [
          {
            "title": "How to Launch a Referral Program in 1 Week",
            "steps": [
              "Day 1-2: Design dual incentive (give X to referrer AND referee)",
              "Day 3-4: Build tracking with unique codes (use Rewardful or ReferralCandy)"
            ],
            "outcome": "100+ referrals in first month",
            "source_url": "https://..."
          }
        ],
        "visual_elements": [
          {
            "url": "https://.../diagram.png",
            "type": "image",
            "platform": "image",
            "description": "4-step validation framework with decision points",
            "embed_recommended": false,
            "source_url": "https://..."
          },
          {
            "url": "https://youtube.com/watch?v=...",
            "type": "video",
            "platform": "youtube",
            "description": "YC partners explain validation framework",
            "embed_recommended": false,
            "source_url": "https://..."
          }
        ],
        "downloadable_resources": [
          {
            "title": "Customer Interview Script Template",
            "type": "google_doc",
            "url": "https://docs.google.com/...",
            "description": "15-question interview script with follow-up prompts"
          }
        ],
        "recommended_tools": [
          {
            "tool_name": "Typeform",
            "category": "Survey/Research",
            "use_case": "Create professional customer interview surveys",
            "pricing": "Free tier available, paid from $25/mo",
            "url": "https://typeform.com",
            "why_recommended": "Conditional logic for better interview flow"
          }
        ],
        "internal_link_opportunities": [
          {
            "anchor_text": "customer interview best practices",
            "target_article_title": "How to Conduct Customer Interviews",
            "placement": "in_section_3",
            "relevance_reason": "Natural follow-up for readers learning about validation"
          }
        ],
        "cta_placements": [
          {
            "cta_text": "Start Your Free Trial",
            "cta_url": "https://example.com/signup",
            "placement": "end_of_section_4",
            "context": "After explaining validation process, offer tool to help"
          }
        ],
        "competitive_analysis": {
          "common_topics": ["validation frameworks", "customer interviews", "MVP testing"],
          "content_gaps": ["cost breakdown for different methods", "failure examples"],
          "average_word_count": 2847,
          "recommended_approach": "Focus on tactical frameworks with decision trees and real cost estimates"
        }
      }
    JSON
  end

  def transform_grounding_to_serp_format(grounding_data, metadata)
    # Separate videos from images
    visual_elements = grounding_data["visual_elements"] || []
    images = visual_elements.select { |v| v["type"] == "image" }
    videos = visual_elements.select { |v| v["type"] == "video" }

    {
      # Core data from grounding
      "detailed_examples" => grounding_data["examples"] || [],
      "statistics" => grounding_data["statistics"] || [],
      "faqs" => grounding_data["faqs"] || [],
      "people_also_ask" => grounding_data["people_also_ask"] || [],

      # Visual elements
      "visual_elements" => {
        "images" => images,
        "videos" => videos
      },

      # Structured content
      "comparison_tables" => {
        "tables" => grounding_data["comparison_tables"] || []
      },
      "step_by_step_guides" => {
        "guides" => grounding_data["step_by_step_guides"] || []
      },
      "downloadable_resources" => {
        "resources" => grounding_data["downloadable_resources"] || []
      },
      "recommended_tools" => grounding_data["recommended_tools"] || [],

      # Internal linking & CTAs
      "internal_link_opportunities" => grounding_data["internal_link_opportunities"] || [],
      "cta_placements" => grounding_data["cta_placements"] || [],

      # Competitive analysis
      "common_topics" => grounding_data.dig("competitive_analysis", "common_topics") || [],
      "content_gaps" => grounding_data.dig("competitive_analysis", "content_gaps") || [],
      "average_word_count" => grounding_data.dig("competitive_analysis", "average_word_count") || 2000,
      "recommended_approach" => grounding_data.dig("competitive_analysis", "recommended_approach") || "",

      # Grounding metadata
      "grounding_metadata" => {
        "sources_count" => metadata[:sources_count],
        "sources" => metadata[:sources],
        "web_search_queries" => metadata[:web_search_queries]
      }
    }
  end
end
