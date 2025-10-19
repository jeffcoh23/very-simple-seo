# app/services/article_writer_service.rb
# Writes the actual article content based on outline, SERP research, and voice profile
class ArticleWriterService
  def initialize(keyword, outline, serp_data, voice_profile: nil, project: nil)
    @keyword = keyword
    @outline = outline
    @serp_data = serp_data
    @voice_profile = voice_profile
    @project = project
  end

  def perform
    Rails.logger.info "Writing article for: #{@keyword}"

    # Write introduction
    intro = write_introduction
    return { data: nil, cost: 0.15 } if intro.nil?

    # Track all written content for context
    @written_sections = [ intro ]
    @used_examples = extract_used_examples(intro)
    @used_statistics = extract_used_statistics(intro)
    @mentioned_tools = extract_mentioned_tools(intro) # NEW: Track tools to prevent duplicates

    # Write each section
    sections = []
    @outline["sections"].each_with_index do |section_outline, i|
      next if section_outline["heading"]&.downcase&.include?("introduction")
      next if section_outline["heading"]&.downcase&.include?("conclusion")

      Rails.logger.info "Writing section #{i + 1}/#{@outline['sections'].size}: #{section_outline['heading']}"

      section_content = write_section(section_outline, i, sections)
      if section_content
        sections << section_content
        @written_sections << section_content
        @used_examples.concat(extract_used_examples(section_content))
        @used_statistics.concat(extract_used_statistics(section_content))
        @mentioned_tools.concat(extract_mentioned_tools(section_content)) # NEW: Track tools
      end
    end

    # Write FAQ section if included in outline
    if @outline["has_faq_section"] && @outline["faq_section"]
      Rails.logger.info "Writing FAQ section"
      faq_content = write_faq_section(@outline["faq_section"])
      sections << faq_content if faq_content
    end

    # Write conclusion
    conclusion = write_conclusion(sections)
    return { data: nil, cost: 0.15 } if conclusion.nil?

    article_markdown = build_article_markdown(intro, sections, conclusion)

    Rails.logger.info "Article written: #{article_markdown.split.size} words"

    { data: article_markdown, cost: 0.15 } # GPT-4o Mini cost
  end

  private

  def write_introduction
    examples = @serp_data["detailed_examples"] || []
    statistics = @serp_data["statistics"] || []

    intro_section = @outline["sections"].find { |s| s["heading"]&.downcase&.include?("introduction") }
    word_count = intro_section&.dig("word_count") || 250

    prompt = <<~PROMPT
      Write an engaging introduction for an article about "#{@keyword}".

      ARTICLE TITLE: #{@outline['title']}

      KEY POINTS TO COVER:
      #{intro_section&.dig('key_points')&.join("\n") || "- Hook the reader\n- Explain why this matters\n- Preview what they'll learn"}

      AVAILABLE EXAMPLES (use 1-2 if relevant):
      #{examples.take(3).map { |ex|
        base = "- #{ex['company']}: #{ex['what_they_did']}"
        base += " (HOW: #{ex['how_they_did_it']})" if ex['how_they_did_it'].present?
        base += " (WHEN: #{ex['timeline']})" if ex['timeline'].present?
        base += " → #{ex['outcome']}"
        base
      }.join("\n")}

      AVAILABLE STATISTICS (use 1-2 if relevant - MUST include citation numbers):
      #{statistics.take(3).map.with_index { |stat, i|
        citation_num = i + 1
        if stat['source_url'].present?
          "- [#{citation_num}] #{stat['stat']} (Source: #{stat['source']})"
        else
          "- #{stat['stat']} (#{stat['source']})"
        end
      }.join("\n")}

      CITATION FORMAT (CRITICAL REQUIREMENT):

      WHEN using a statistic from the list above:
      1. Place citation number at END of sentence: "42% of startups fail due to no market need [1]."
      2. Use ONLY the bracketed number: [1], [2], [3]
      3. DO NOT add source name after citation (it's in Sources section)

      EXAMPLES:
      - ✅ CORRECT: "According to CB Insights research, 42% of startups fail due to no market need [1]."
      - ❌ WRONG: "42% of startups fail (CB Insights)"
      - ❌ WRONG: "42% of startups fail" (missing citation)

      REMEMBER: Every citation [1], [2], [3] will be matched to the Sources section at end of article

      #{voice_instructions}

      #{brand_integration_instructions}

      TARGET: #{word_count} words

      ANTI-PATTERNS (DO NOT DO):
      ❌ Generic fluff: "In today's digital landscape", "In the modern era"
      ❌ Missing citation: "42% of startups fail" (must add [1])
      ❌ Wrong citation: "42% fail (CB Insights)" (must be "42% fail [1]")
      ❌ No brand: Writing entire intro without mentioning #{@project&.name}
      ❌ Vague hook: "Are you wondering about...?" (be specific)

      REQUIRED PATTERNS:
      ✅ Strong hook: "Dropbox got 75,000 signups in 2008—before writing any code."
      ✅ Citations: "42% of startups fail [1]"
      ✅ Brand: "#{@project&.name} helps by..."
      ✅ Specific value: Tell readers exactly what they'll learn

      REQUIREMENTS:
      - Hook reader in first sentence with specific example or stat
      - Use a real example or statistic to establish credibility
      - When using examples, include the HOW and WHEN details provided above for tactical depth
      - When citing statistics, use format shown above: "42% fail [1]"
      - Clearly explain what the article will cover
      - MUST mention #{@project&.name} at least once
      - Write in markdown format
      - DO NOT include the heading (I'll add it)
      - Use natural, conversational tone
    PROMPT

    client = Ai::ClientService.for_article_writing
    response = client.chat(
      messages: [ { role: "user", content: prompt } ],
      max_tokens: 8000,
      temperature: 0.8
    )

    return nil unless response[:success]

    response[:content].strip
  rescue => e
    Rails.logger.error "Introduction writing failed: #{e.message}"
    nil
  end

  def write_section(section_outline, section_index, previous_sections)
    examples = @serp_data["detailed_examples"] || []
    statistics = @serp_data["statistics"] || []
    visual_elements = @serp_data.dig("visual_elements") || {}
    comparison_tables = @serp_data.dig("comparison_tables", "tables") || []
    step_by_step_guides = @serp_data.dig("step_by_step_guides", "guides") || []
    downloadable_resources = @serp_data.dig("downloadable_resources", "resources") || []
    recommended_tools = @serp_data["recommended_tools"] || []

    heading = section_outline["heading"]
    word_count = section_outline["word_count"] || 400
    key_points = section_outline["key_points"] || []
    subsections = section_outline["subsections"] || []

    # Get CTAs for this section
    section_ctas = (@outline["cta_placements"] || []).select do |cta|
      cta["placement"]&.include?("section_#{section_index + 1}") ||
      cta["placement"]&.include?("after_section_#{section_index + 1}")
    end

    # Build previous context (last 2 sections for brevity)
    previous_context = build_previous_context(previous_sections.last(2))

    # Filter out already-used examples and statistics
    available_examples = filter_unused_examples(examples)
    available_statistics = filter_unused_statistics(statistics)

    # Build visual elements section
    visuals_text = build_visuals_prompt(visual_elements)
    tables_text = build_tables_prompt(comparison_tables)
    guides_text = build_guides_prompt(step_by_step_guides)
    resources_text = build_resources_prompt(downloadable_resources)
    tools_text = build_tools_prompt(recommended_tools, @mentioned_tools || []) # Pass already-mentioned tools

    # NEW: Build internal links (from scraped sitemap) and CTAs prompts
    internal_links_text = build_internal_links_prompt([]) # Scraped pages fetched inside method
    ctas_text = build_ctas_prompt(section_ctas)

    prompt = <<~PROMPT
      Write a section for an article about "#{@keyword}".

      #{previous_context}

      SECTION HEADING: #{heading}

      KEY POINTS TO COVER:
      #{key_points.map { |p| "- #{p}" }.join("\n")}

      #{subsections.any? ? "SUBSECTIONS TO INCLUDE:\n#{subsections.map { |s| "- #{s['heading']}: #{s['key_points']&.join(', ')}" }.join("\n")}" : ""}

      AVAILABLE EXAMPLES (use 2-3 if relevant):
      #{available_examples.take(5).map { |ex|
        base = "- #{ex['company']}: #{ex['what_they_did']}"
        base += " (HOW: #{ex['how_they_did_it']})" if ex['how_they_did_it'].present?
        base += " (WHEN: #{ex['timeline']})" if ex['timeline'].present?
        base += " → #{ex['outcome']}"
        base
      }.join("\n")}

      AVAILABLE STATISTICS (use 2-3 if relevant - MUST include citation numbers):
      #{available_statistics.take(5).map.with_index { |stat, i|
        citation_num = (@used_statistics.size + i + 1) # Continue numbering from previous sections
        if stat['source_url'].present?
          "- [#{citation_num}] #{stat['stat']} (Source: #{stat['source']})"
        else
          "- #{stat['stat']} (#{stat['source']})"
        end
      }.join("\n")}

      CITATION FORMAT (CRITICAL REQUIREMENT):

      WHEN using a statistic:
      1. Place [#{(@used_statistics.size + 1)}] at END of sentence: "38% skip validation [#{(@used_statistics.size + 1)}]."
      2. Use ONLY the bracketed number, NOT source name
      3. Sources listed at end of article

      EXAMPLES:
      - ✅ CORRECT: "Research shows 38% of founders skip validation entirely [#{(@used_statistics.size + 1)}]."
      - ❌ WRONG: "38% skip validation (Statista)"
      - ❌ WRONG: "38% skip validation" (missing citation)

      #{visuals_text}

      #{tables_text}

      #{guides_text}

      #{resources_text}

      #{tools_text}

      #{internal_links_text}

      #{ctas_text}

      EXAMPLES ALREADY USED (DO NOT repeat these):
      #{@used_examples.uniq.join(", ")}

      STATISTICS ALREADY USED (DO NOT repeat these):
      #{@used_statistics.uniq.take(5).join("; ")}

      #{voice_instructions}

      TARGET: #{word_count} words

      ANTI-PATTERNS (DO NOT DO):
      ❌ Generic fluff: "It's important to note", "Remember that"
      ❌ Vague examples: "Dropbox validated their idea" (missing HOW/WHEN details)
      ❌ Missing citations: "42% of startups fail" (must add [#{(@used_statistics.size + 1)}])
      ❌ No brand: Writing entire section without mentioning #{@project&.name}
      ❌ Tool spam: "Use Typeform, Google Forms, SurveyMonkey, or..." (max 1 tool!)
      ❌ Unlinked CTA: "Start your free trial" (must hyperlink!)
      ❌ Repeating content: Using same examples/stats from previous sections

      REQUIRED PATTERNS:
      ✅ Specific examples: "Dropbox posted 3-minute demo on Hacker News in 2008, got 75,000 signups"
      ✅ Citations: "42% fail [#{(@used_statistics.size + 1)}]"
      ✅ Brand: "#{@project&.name} streamlines..."
      ✅ Max 1 tool: "Tools like Typeform can help" (not "Typeform, Google Forms, etc.")
      ✅ Hyperlinked CTAs: **[CTA text](url)**

      REQUIREMENTS:
      - Write in markdown format
      - Include the H2 heading: ## #{heading}
      - Use H3 headings (###) for subsections
      - DO NOT repeat any examples or statistics already used in previous sections
      - Use DIFFERENT examples from the available list above
      - When using examples, include the HOW and WHEN details provided above for tactical depth
      - When citing statistics, use format shown above
      - Include bullet points or numbered lists where appropriate
      - Keep paragraphs short (2-4 sentences)
      - Make it actionable and specific with HOW details, not just WHAT
      - Include internal links naturally in context (not forced or awkward)
      - Place CTAs at the END of this section if provided (not in the middle)
    PROMPT

    client = Ai::ClientService.for_article_writing
    response = client.chat(
      messages: [ { role: "user", content: prompt } ],
      max_tokens: 8000,
      temperature: 0.8
    )

    return nil unless response[:success]

    response[:content].strip
  rescue => e
    Rails.logger.error "Section #{section_index} writing failed: #{e.message}"
    nil
  end

  def write_conclusion(sections)
    conclusion_section = @outline["sections"].find { |s| s["heading"]&.downcase&.include?("conclusion") }
    word_count = conclusion_section&.dig("word_count") || 200

    # Get section headings for context
    section_headings = @outline["sections"]
      .reject { |s| s["heading"]&.downcase&.include?("introduction") || s["heading"]&.downcase&.include?("conclusion") }
      .map { |s| s["heading"] }

    prompt = <<~PROMPT
      Write a conclusion for an article about "#{@keyword}".

      ARTICLE TITLE: #{@outline['title']}

      MAIN SECTIONS COVERED:
      #{section_headings.map { |h| "- #{h}" }.join("\n")}

      KEY POINTS TO COVER:
      #{conclusion_section&.dig('key_points')&.join("\n") || "- Summarize main takeaways\n- Call to action\n- Final thought"}

      #{voice_instructions}

      #{brand_integration_instructions}

      #{conclusion_cta_instructions}

      TARGET: #{word_count} words

      ANTI-PATTERNS (DO NOT DO):
      ❌ Vague summary: "We covered a lot today"
      ❌ Generic CTA: "Start your journey today", "Take the first step"
      ❌ Motivational fluff: "Are you ready to take the leap?"
      ❌ AI clichés: "In conclusion", "To sum up", "At the end of the day"
      ❌ No brand: Ending without mentioning #{@project&.name}
      ❌ Unlinked CTA: "Start your free trial" (must hyperlink!)

      REQUIRED PATTERNS:
      ✅ Specific takeaways: "1. Run 10 interviews by Friday, 2. Build landing page, 3. Get 5 to pay $1"
      ✅ Concrete next step: "Book your first 5 interviews by Friday using the script in Section 2"
      ✅ Brand + CTA: "Use #{@project&.name} to..." with hyperlinked CTA
      ✅ Hyperlinked CTAs: **[CTA text](url)**

      REQUIREMENTS:
      - Start with a strong summary of the 3 MOST IMPORTANT actionable takeaways (be specific, not vague)
      - Provide ONE concrete next step readers can take immediately (not generic "take action")
      - Give SPECIFIC actions: "Book 5 customer interviews by Friday using the script in Section 2"
      - MUST mention #{@project&.name} and include hyperlinked CTA
      - Write in markdown format
      - DO NOT include the heading (I'll add it)

      GOOD CONCLUSION EXAMPLE:
      "Validating your business idea comes down to three actions:
      1. Run 10+ customer interviews using the question framework in Section 2
      2. Build a landing page and aim for 30+ signups in 2 weeks
      3. Create a basic prototype and get 5 people to pay $1

      Start with customer interviews this week. Use the script above and book your first 5 conversations by Friday. This single step will tell you more than months of planning."

      Write in this direct, specific, actionable style.
    PROMPT

    client = Ai::ClientService.for_article_writing
    response = client.chat(
      messages: [ { role: "user", content: prompt } ],
      max_tokens: 8000,
      temperature: 0.8
    )

    return nil unless response[:success]

    response[:content].strip
  rescue => e
    Rails.logger.error "Conclusion writing failed: #{e.message}"
    nil
  end

  def write_faq_section(faq_section_outline)
    faqs = @serp_data["faqs"] || []
    return nil if faqs.empty?

    heading = faq_section_outline["heading"] || "Frequently Asked Questions"
    word_count = faq_section_outline["word_count"] || 600
    questions_to_include = faq_section_outline["questions_to_include"] || []

    # Match FAQs from SERP data with questions_to_include
    selected_faqs = questions_to_include.map do |question_text|
      faqs.find { |faq| faq["question"]&.downcase&.include?(question_text.downcase) || question_text.downcase.include?(faq["question"]&.downcase || "") }
    end.compact

    # If outline didn't specify questions, take first 8-12 from SERP data
    selected_faqs = faqs.take(10) if selected_faqs.empty?

    faqs_text = selected_faqs.map do |faq|
      text = "**Q: #{faq['question']}**\n\n#{faq['answer']}"
      text += " ([Source](#{faq['source_url']}))" if faq["source_url"].present?
      text
    end.join("\n\n")

    prompt = <<~PROMPT
      Write a FAQ section for an article about "#{@keyword}".

      AVAILABLE FAQs (use these questions and answers):
      #{faqs_text}

      #{voice_instructions}

      TARGET: #{word_count} words (approximately #{selected_faqs.size} Q&A pairs)

      REQUIREMENTS:
      - Write in markdown format
      - Include the H2 heading: ## #{heading}
      - Format each FAQ as:
        ### Question text here?
        Answer text here with details and examples.

      - Keep answers concise but complete (2-4 sentences each)
      - Use the exact questions and answers provided above
      - Maintain source citations in answers where provided
      - Add brief context or examples to make answers more useful
      - Avoid repeating information already covered in main article
      - Order questions from most common to more specific
    PROMPT

    client = Ai::ClientService.for_article_writing
    response = client.chat(
      messages: [ { role: "user", content: prompt } ],
      max_tokens: 8000,
      temperature: 0.7
    )

    return nil unless response[:success]

    response[:content].strip
  rescue => e
    Rails.logger.error "FAQ section writing failed: #{e.message}"
    nil
  end

  def build_article_markdown(intro, sections, conclusion)
    parts = []

    # Title
    parts << "# #{@outline['title']}\n"

    # Introduction
    parts << "#{intro}\n"

    # Table of Contents (SEO best practice)
    toc = generate_table_of_contents
    parts << "\n#{toc}\n" if toc.present?

    # Sections (already include their own headings)
    sections.each do |section|
      parts << "\n#{section}\n"
    end

    # Conclusion
    parts << "\n## Conclusion\n"
    parts << "#{conclusion}\n"

    # Sources section (SEO best practice - builds E-E-A-T)
    sources = generate_sources_section
    parts << "\n#{sources}\n" if sources.present?

    parts.join("\n")
  end

  def voice_instructions
    return "" unless @voice_profile.present?

    <<~VOICE
      VOICE PROFILE - MATCH THIS STYLE:
      #{@voice_profile}

      Write in this exact tone and style.
    VOICE
  end

  # NEW: Brand integration instructions for prompts
  def brand_integration_instructions
    return "" unless @project

    <<~BRAND
      BRAND INTEGRATION (REQUIRED):
      - Product: #{@project.name}
      - Domain: #{@project.domain}
      - MUST mention #{@project.name} at least 1-2 times in this section
      - Natural placements: "Tools like #{@project.name}", "#{@project.name} helps by", "Use #{@project.name} to"
      - ❌ WRONG: Skip mentioning our product entirely
      - ✅ CORRECT: "#{@project.name} streamlines this process by..."
      - This is OUR article promoting OUR product - brand mentions are mandatory, not optional
    BRAND
  end

  def brand_mention_instruction
    @project ? "Consider mentioning #{@project.name} if contextually relevant (1-2x)" : ""
  end

  # NEW: Conclusion-specific brand CTA instructions
  def conclusion_cta_instructions
    return "" unless @project

    project_ctas = @outline&.dig("cta_placements") || []
    final_cta = project_ctas.last

    if final_cta
      <<~CTA
        FINAL CALL TO ACTION (required at end):
        - End with: **[#{final_cta['cta_text']}](#{final_cta['cta_url']})** and [specific outcome/benefit]
        - Example: "Start with #{@project.name} to test your idea against AI personas in under an hour, then validate with real customers."
      CTA
    else
      <<~CTA
        FINAL CALL TO ACTION:
        - End with mention of #{@project.name} as next step
        - Example: "Use #{@project.name} to [relevant benefit for #{@keyword}]"
      CTA
    end
  end

  def conclusion_brand_instruction
    @project ? "End with a call to action mentioning #{@project.name} and its specific benefit" : "End with a clear next step"
  end

  # Build context from previous sections (for flow and avoiding repetition)
  def build_previous_context(previous_sections)
    return "" if previous_sections.empty?

    # Truncate each section to first 200 chars (just headings + opening)
    previews = previous_sections.map do |section|
      truncated = section[0..200].gsub("\n", " ")
      "#{truncated}..."
    end

    <<~CONTEXT
      PREVIOUS SECTIONS (for context - maintain flow, don't repeat):
      #{previews.join("\n\n")}
    CONTEXT
  end

  # Extract company names used in text
  def extract_used_examples(text)
    return [] if text.nil? || text.empty?

    examples = @serp_data["detailed_examples"] || []
    used = []

    examples.each do |ex|
      company = ex["company"]
      next if company.nil? || company.empty? # Skip nil/empty company names

      # Check if company name appears in text (case-insensitive)
      used << company if text =~ /#{Regexp.escape(company)}/i
    end

    used
  end

  # Extract statistics used in text
  def extract_used_statistics(text)
    return [] if text.nil? || text.empty?

    statistics = @serp_data["statistics"] || []
    used = []

    statistics.each do |stat|
      stat_text = stat["stat"]
      next if stat_text.nil? || stat_text.empty? # Skip nil/empty stats

      # Check if stat appears in text
      used << stat_text if text.include?(stat_text)
    end

    used
  end

  # Filter out examples that have already been used
  def filter_unused_examples(all_examples)
    return [] if all_examples.nil?

    all_examples.reject do |ex|
      @used_examples.include?(ex["company"])
    end
  end

  # Filter out statistics that have already been used
  def filter_unused_statistics(all_statistics)
    return [] if all_statistics.nil?

    all_statistics.reject do |stat|
      @used_statistics.include?(stat["stat"])
    end
  end

  # Build prompt text for visual elements
  def build_visuals_prompt(visual_elements)
    images = visual_elements["images"] || []
    videos = visual_elements["videos"] || []

    return "" if images.empty? && videos.empty?

    parts = []
    parts << "VISUAL ELEMENTS AVAILABLE:"

    unless images.empty?
      parts << "Images:"
      images.each do |img|
        parts << "  - #{img['description']}"
        parts << "    URL: #{img['url']}"
      end
    end

    unless videos.empty?
      parts << "Videos:"
      videos.each do |vid|
        parts << "  - #{vid['description']}"
        parts << "    URL: #{vid['url']}"
      end
    end

    parts << ""
    parts << "VISUAL USAGE GUIDELINES:"
    parts << "- Embed 1-2 relevant images using: ![Description](url)"
    parts << "- NEVER use the same image more than once in the entire article"
    parts << "- If only 1 image available, use it in the MOST relevant section only"
    parts << "- If no relevant images for this section, skip images entirely (better than forcing it)"
    parts << "- Add descriptive captions AFTER images using italics: *Caption text explaining what the image shows*"
    parts << "- Link to videos when highly relevant: [Watch: Tutorial name](video_url)"
    parts << "- Place visuals AFTER explaining the concept (not at start of section)"
    parts << "- Only use visuals that directly support your points"

    parts.join("\n")
  end

  # Build prompt text for comparison tables
  def build_tables_prompt(tables)
    return "" if tables.empty?

    parts = []
    parts << "COMPARISON TABLES AVAILABLE:"

    tables.each_with_index do |table, i|
      parts << "#{i + 1}. #{table['title']}"
      parts << "   Headers: #{table['headers'].join(' | ')}"
      parts << "   Rows: #{table['rows'].size} rows of data"
    end

    parts << ""
    parts << "TABLE USAGE GUIDELINES:"
    parts << "- Include 1 comparison table if highly relevant to this section"
    parts << "- Use markdown table format:"
    parts << "  | Header 1 | Header 2 | Header 3 |"
    parts << "  |----------|----------|----------|"
    parts << "  | Data 1   | Data 2   | Data 3   |"
    parts << "- Add context BEFORE the table: 'Here's how they compare:'"
    parts << "- Add takeaway AFTER the table: '**Bottom line:** Choose X if...'"
    parts << "- Only use tables that directly answer reader questions"

    parts.join("\n")
  end

  # Build prompt text for step-by-step guides
  def build_guides_prompt(guides)
    return "" if guides.empty?

    parts = []
    parts << "STEP-BY-STEP GUIDES AVAILABLE:"

    guides.each_with_index do |guide, i|
      parts << "#{i + 1}. #{guide['title']}"
      parts << "   Steps: #{guide['steps'].size} actionable steps"
      parts << "   Outcome: #{guide['outcome']}" if guide["outcome"]
    end

    parts << ""
    parts << "GUIDE USAGE GUIDELINES:"
    parts << "- Include 1 actionable guide if highly relevant to this section"
    parts << "- Use numbered list format with bold labels:"
    parts << "  1. **Day 1-2:** Action with specific details"
    parts << "  2. **Day 3-4:** Next action with tools/timelines"
    parts << "- Add expected outcome at the end"
    parts << "- Make each step specific with tools, timelines, or exact actions"
    parts << "- Only use guides that provide immediate value to readers"

    parts.join("\n")
  end

  # Build prompt text for downloadable resources
  def build_resources_prompt(resources)
    return "" if resources.empty?

    # LIMIT: Max 2 resources
    limited_resources = resources.take(2)

    parts = []
    parts << "EXTERNAL RESOURCES (use very sparingly):"

    limited_resources.each_with_index do |resource, i|
      parts << "#{i + 1}. #{resource['title']} (#{resource['type']})"
      parts << "   #{resource['description']}"
    end

    parts << ""
    parts << "RESOURCE MENTION RULES (IMPORTANT):"
    parts << "- DO NOT link to external templates/resources from competitors"
    parts << "- These are provided for awareness only - DO NOT promote them"
    parts << "- Instead, focus on teaching the concept directly in your content"
    parts << "- If resources would be helpful, suggest readers create their own based on the principles you explain"
    parts << "- NEVER say 'Download from [External Site]' - that promotes competitors"
    parts << "- Keep focus on #{@project&.name || 'our solution'} when relevant"

    parts.join("\n")
  end

  # Build prompt text for recommended tools
  def build_tools_prompt(tools, already_mentioned = [])
    return "" if tools.empty?

    # Filter out already-mentioned tools
    available_tools = tools.reject { |t| already_mentioned.include?(t["tool_name"]) }

    # Limit to 2 tools max per section
    limited_tools = available_tools.take(2)

    return "" if limited_tools.empty?

    parts = []
    parts << "TOOLS AVAILABLE (VERY LIMITED USE):"
    parts << ""

    limited_tools.each_with_index do |tool, i|
      parts << "#{i + 1}. #{tool['tool_name']} - #{tool['category']}"
      parts << "   Use case: #{tool['use_case']}"
      parts << "   URL: #{tool['url']}"
      parts << ""
    end

    if already_mentioned.any?
      parts << "TOOLS ALREADY MENTIONED IN PREVIOUS SECTIONS (DO NOT REPEAT):"
      parts << already_mentioned.join(", ")
      parts << ""
    end

    parts << "TOOL MENTION RULES (STRICT LIMITS):"
    parts << "- ✅ ALLOWED: Mention maximum 1 tool from list above (or 0 if not relevant)"
    parts << "- ❌ FORBIDDEN: Mentioning same tool twice in article"
    parts << "- ❌ FORBIDDEN: Creating comparison tables with multiple tools"
    parts << "- ❌ FORBIDDEN: Listing multiple tools ('Use Typeform, Google Forms, or...')"
    parts << "- PRIORITY: Focus on #{@project&.name || 'our solution'} over third-party tools"
    parts << "- FORMAT: Brief mention only - 'Tools like Typeform can help with surveys'"

    parts.join("\n")
  end

  # Build prompt text for internal links
  def build_internal_links_prompt(internal_links)
    # NEW: Use scraped sitemap pages instead of database articles
    scraped_pages = get_scraped_pages
    return "" if scraped_pages.empty?

    parts = []
    parts << "INTERNAL PAGES AVAILABLE FOR LINKING:"

    scraped_pages.take(5).each_with_index do |page, i|
      parts << "#{i + 1}. #{page['title']}"
      parts << "   URL: #{page['url']}"
      parts << "   Description: #{page['meta_description'][0..100]}..." if page["meta_description"].present?
    end

    parts << ""
    parts << "INTERNAL LINKING RULES (IMPORTANT):"
    parts << "- Link to 2-3 of these pages NATURALLY where contextually relevant"
    parts << "- Use REAL URLs provided above (not /articles/:id)"
    parts << "- Format: [descriptive anchor text](actual-url)"
    parts << "- Example: 'Check our [pricing plans](#{scraped_pages.first['url']}) for details.'"
    parts << "- Make links helpful to readers, not forced"
    parts << "- These are OUR pages - prioritize linking to them over external sites"

    parts.join("\n")
  end

  # Get scraped pages from project's sitemap data
  def get_scraped_pages
    return [] unless @project&.internal_content_index.present?

    pages = @project.internal_content_index["pages"] || []
    return [] if pages.empty?

    # Return scraped pages (already includes title, url, meta_description)
    pages
  end

  # Build prompt text for CTAs
  def build_ctas_prompt(ctas)
    return "" if ctas.empty?

    parts = []
    parts << "CALL-TO-ACTION (CRITICAL - MUST HYPERLINK):"
    parts << ""

    ctas.each_with_index do |cta, i|
      parts << "#{i + 1}. Text: \"#{cta['cta_text']}\""
      parts << "   URL: #{cta['cta_url']}"
      parts << "   REQUIRED FORMAT: **[#{cta['cta_text']}](#{cta['cta_url']})**"
      parts << "   Context: #{cta['context']}"
      parts << ""
    end

    parts << "CTA PLACEMENT RULES (NON-NEGOTIABLE):"
    parts << "- Place CTA at the END of this section (after all content)"
    parts << "- MUST use EXACT markdown link format shown above"
    parts << "- ❌ WRONG: '#{ctas.first['cta_text']}' (plain text, no link)"
    parts << "- ✅ CORRECT: '**[#{ctas.first['cta_text']}](#{ctas.first['cta_url']})**'"
    parts << "- Example: 'Ready to validate your idea? **[#{ctas.first['cta_text']}](#{ctas.first['cta_url']})** and get instant feedback.'"
    parts << "- The CTA text MUST be a clickable hyperlink, not plain text"

    parts.join("\n")
  end

  # Generate Table of Contents from outline sections
  def generate_table_of_contents
    sections = @outline["sections"] || []

    # Only generate TOC if we have 3+ sections (excluding intro/conclusion)
    content_sections = sections.reject do |s|
      heading = s["heading"]&.downcase || ""
      heading.include?("introduction") || heading.include?("conclusion")
    end

    return "" if content_sections.size < 3

    toc_parts = []
    toc_parts << "## Table of Contents\n"

    content_sections.each_with_index do |section, i|
      heading = section["heading"]
      # Create anchor (lowercase, hyphens, no special chars)
      anchor = heading.downcase
                      .gsub(/[^a-z0-9\s-]/, "")
                      .gsub(/\s+/, "-")
                      .gsub(/-+/, "-")
                      .gsub(/^-|-$/, "")

      toc_parts << "#{i + 1}. [#{heading}](##{anchor})"
    end

    # Add FAQ if present
    if @outline["has_faq_section"]
      toc_parts << "#{content_sections.size + 1}. [Frequently Asked Questions](#frequently-asked-questions)"
    end

    toc_parts << "" # Empty line after TOC
    toc_parts.join("\n")
  end

  # Generate Sources section from SERP data
  def generate_sources_section
    sources = []
    citation_counter = 0

    # Collect sources from statistics
    if @serp_data["statistics"].is_a?(Array)
      @serp_data["statistics"].each do |stat|
        if stat["source_url"].present? && stat["source"].present?
          citation_counter += 1
          sources << {
            number: citation_counter,
            title: stat["source"],
            url: stat["source_url"]
          }
        end
      end
    end

    # Collect sources from examples
    if @serp_data["detailed_examples"].is_a?(Array)
      @serp_data["detailed_examples"].each do |example|
        if example["source_url"].present?
          # Avoid duplicates
          unless sources.any? { |s| s[:url] == example["source_url"] }
            citation_counter += 1
            sources << {
              number: citation_counter,
              title: example["company"] || example["source"] || "Source",
              url: example["source_url"]
            }
          end
        end
      end
    end

    return "" if sources.empty?

    sources_parts = []
    sources_parts << "## Sources\n"

    sources.each do |source|
      sources_parts << "[#{source[:number]}] #{source[:title]}"
      sources_parts << "    #{source[:url]}\n"
    end

    sources_parts.join("\n")
  end

  # NEW: Extract tool names mentioned in content to prevent duplicates
  def extract_mentioned_tools(content)
    return [] if content.blank?

    # List of common tools to track
    known_tools = [
      "Typeform", "Google Forms", "SurveyMonkey", "Optimizely",
      "Mixpanel", "Google Analytics", "Unbounce", "Hotjar",
      "Mailchimp", "ConvertKit", "HubSpot", "Intercom",
      "Calendly", "Zoom", "Loom", "Figma", "Canva"
    ]

    mentioned = []
    known_tools.each do |tool|
      mentioned << tool if content.include?(tool)
    end

    mentioned
  end
end
