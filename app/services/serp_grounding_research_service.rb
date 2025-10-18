# app/services/serp_grounding_research_service.rb
# Replaces SerpResearchService with Google Grounding API
# Uses comprehensive web search instead of HTML scraping
# Includes: examples, stats, FAQs, tables, guides, videos, tools, internal links, CTAs

class SerpGroundingResearchService
  def initialize(keyword, project: nil)
    @keyword = keyword
    @project = project
    @grounding = GoogleGroundingService.new(provider: :gemini_grounding)
    # To switch providers: GoogleGroundingService.new(provider: :perplexity)
  end

  def perform
    Rails.logger.info "Starting Grounding research for: #{@keyword}"

    # Build context about project's existing content
    internal_context = build_internal_context

    prompt = build_comprehensive_research_prompt(internal_context)
    json_structure = build_json_structure_hint

    result = @grounding.search_json(
      prompt,
      json_structure_hint: json_structure,
      max_tokens: 16000
    )

    unless result[:success]
      Rails.logger.error "Grounding search failed: #{result[:error]}"
      return { data: nil, cost: 0.05 }
    end

    # Transform grounding data to match current SERP data structure
    serp_data = transform_grounding_to_serp_format(result[:data], result[:grounding_metadata])

    Rails.logger.info "Grounding research complete:"
    Rails.logger.info "  - Examples: #{serp_data['detailed_examples']&.size || 0}"
    Rails.logger.info "  - Statistics: #{serp_data['statistics']&.size || 0}"
    Rails.logger.info "  - FAQs: #{serp_data['faqs']&.size || 0}"
    Rails.logger.info "  - Internal Links: #{serp_data['internal_link_opportunities']&.size || 0}"
    Rails.logger.info "  - CTAs: #{serp_data['cta_placements']&.size || 0}"
    Rails.logger.info "  - Sources: #{result[:grounding_metadata][:sources_count]}"

    { data: serp_data, cost: 0.05 } # Estimate: much cheaper than 9 AI calls
  end

  private

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
    return "" unless internal_context && internal_context['existing_articles']&.any?

    existing_articles = internal_context['existing_articles']
    ctas = internal_context['ctas'] || []

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
    visual_elements = grounding_data['visual_elements'] || []
    images = visual_elements.select { |v| v['type'] == 'image' }
    videos = visual_elements.select { |v| v['type'] == 'video' }

    {
      # Core data from grounding
      'detailed_examples' => grounding_data['examples'] || [],
      'statistics' => grounding_data['statistics'] || [],
      'faqs' => grounding_data['faqs'] || [],
      'people_also_ask' => grounding_data['people_also_ask'] || [],

      # Visual elements
      'visual_elements' => {
        'images' => images,
        'videos' => videos
      },

      # Structured content
      'comparison_tables' => {
        'tables' => grounding_data['comparison_tables'] || []
      },
      'step_by_step_guides' => {
        'guides' => grounding_data['step_by_step_guides'] || []
      },
      'downloadable_resources' => {
        'resources' => grounding_data['downloadable_resources'] || []
      },
      'recommended_tools' => grounding_data['recommended_tools'] || [],

      # Internal linking & CTAs
      'internal_link_opportunities' => grounding_data['internal_link_opportunities'] || [],
      'cta_placements' => grounding_data['cta_placements'] || [],

      # Competitive analysis
      'common_topics' => grounding_data.dig('competitive_analysis', 'common_topics') || [],
      'content_gaps' => grounding_data.dig('competitive_analysis', 'content_gaps') || [],
      'average_word_count' => grounding_data.dig('competitive_analysis', 'average_word_count') || 2000,
      'recommended_approach' => grounding_data.dig('competitive_analysis', 'recommended_approach') || '',

      # Grounding metadata
      'grounding_metadata' => {
        'sources_count' => metadata[:sources_count],
        'sources' => metadata[:sources],
        'web_search_queries' => metadata[:web_search_queries]
      }
    }
  end
end
