# app/services/article_writer_service.rb
# Writes the actual article content based on outline, SERP research, and voice profile
class ArticleWriterService
  def initialize(keyword, outline, serp_data, voice_profile: nil)
    @keyword = keyword
    @outline = outline
    @serp_data = serp_data
    @voice_profile = voice_profile
  end

  def perform
    Rails.logger.info "Writing article for: #{@keyword}"

    # Write introduction
    intro = write_introduction
    return { data: nil, cost: 0.15 } if intro.nil?

    # Track all written content for context
    @written_sections = [intro]
    @used_examples = extract_used_examples(intro)
    @used_statistics = extract_used_statistics(intro)

    # Write each section
    sections = []
    @outline['sections'].each_with_index do |section_outline, i|
      next if section_outline['heading']&.downcase&.include?('introduction')
      next if section_outline['heading']&.downcase&.include?('conclusion')

      Rails.logger.info "Writing section #{i + 1}/#{@outline['sections'].size}: #{section_outline['heading']}"

      section_content = write_section(section_outline, i, sections)
      if section_content
        sections << section_content
        @written_sections << section_content
        @used_examples.concat(extract_used_examples(section_content))
        @used_statistics.concat(extract_used_statistics(section_content))
      end
    end

    # Write FAQ section if included in outline
    if @outline['has_faq_section'] && @outline['faq_section']
      Rails.logger.info "Writing FAQ section"
      faq_content = write_faq_section(@outline['faq_section'])
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
    examples = @serp_data['detailed_examples'] || []
    statistics = @serp_data['statistics'] || []

    intro_section = @outline['sections'].find { |s| s['heading']&.downcase&.include?('introduction') }
    word_count = intro_section&.dig('word_count') || 250

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

      AVAILABLE STATISTICS (use 1-2 if relevant):
      #{statistics.take(3).map { |stat|
        if stat['source_url'].present?
          "- #{stat['stat']} ([#{stat['source']}](#{stat['source_url']}))"
        else
          "- #{stat['stat']} (#{stat['source']})"
        end
      }.join("\n")}

      #{voice_instructions}

      TARGET: #{word_count} words

      REQUIREMENTS:
      - Hook reader in first sentence
      - Use a real example or statistic to establish credibility
      - When using examples, include the HOW and WHEN details provided above for tactical depth
      - When citing statistics, use the hyperlinked format shown above (e.g., "According to [CB Insights](url), 42%...")
      - Clearly explain what the article will cover
      - Write in markdown format
      - DO NOT include the heading (I'll add it)
      - Use natural, conversational tone
      - Avoid AI clichés like "in today's digital landscape" or "in conclusion"
    PROMPT

    client = Ai::ClientService.for_article_writing
    response = client.chat(
      messages: [{ role: "user", content: prompt }],
      max_tokens: (word_count * 2).to_i, # Tokens ≈ words * 1.3, give buffer
      temperature: 0.8
    )

    return nil unless response[:success]

    response[:content].strip
  rescue => e
    Rails.logger.error "Introduction writing failed: #{e.message}"
    nil
  end

  def write_section(section_outline, section_index, previous_sections)
    examples = @serp_data['detailed_examples'] || []
    statistics = @serp_data['statistics'] || []
    visual_elements = @serp_data.dig('visual_elements') || {}
    comparison_tables = @serp_data.dig('comparison_tables', 'tables') || []
    step_by_step_guides = @serp_data.dig('step_by_step_guides', 'guides') || []
    downloadable_resources = @serp_data.dig('downloadable_resources', 'resources') || []
    recommended_tools = @serp_data['recommended_tools'] || []

    heading = section_outline['heading']
    word_count = section_outline['word_count'] || 400
    key_points = section_outline['key_points'] || []
    subsections = section_outline['subsections'] || []

    # NEW: Get internal links and CTAs for this section
    internal_links = section_outline['internal_links'] || []
    section_ctas = (@outline['cta_placements'] || []).select do |cta|
      cta['placement']&.include?("section_#{section_index + 1}") ||
      cta['placement']&.include?("after_section_#{section_index + 1}")
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
    tools_text = build_tools_prompt(recommended_tools)

    # NEW: Build internal links and CTAs prompts
    internal_links_text = build_internal_links_prompt(internal_links)
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

      AVAILABLE STATISTICS (use 2-3 if relevant):
      #{available_statistics.take(5).map { |stat|
        if stat['source_url'].present?
          "- #{stat['stat']} ([#{stat['source']}](#{stat['source_url']}))"
        else
          "- #{stat['stat']} (#{stat['source']})"
        end
      }.join("\n")}

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

      REQUIREMENTS:
      - Write in markdown format
      - Include the H2 heading: ## #{heading}
      - Use H3 headings (###) for subsections
      - DO NOT repeat any examples or statistics already used in previous sections
      - Reference previous sections naturally if relevant (e.g., "As mentioned earlier...")
      - Use DIFFERENT examples from the available list above
      - When using examples, include the HOW and WHEN details provided above for tactical depth
      - GOOD: "Dropbox validated demand in 2008 by posting a 3-minute demo on Hacker News—before writing any code—and got 75,000 signups overnight"
      - BAD: "Dropbox validated their idea with a demo video"
      - When citing statistics, ALWAYS use the hyperlinked format shown above (e.g., "According to [CB Insights](url), 42%...")
      - Include bullet points or numbered lists where appropriate
      - Keep paragraphs short (2-4 sentences)
      - Use natural, conversational tone
      - Avoid AI clichés like "it's important to note" or "remember"
      - Make it actionable and specific with HOW details, not just WHAT
      - Embed visuals, tables, guides, resources, and tools when HIGHLY relevant to this section
      - Include internal links naturally in context (not forced or awkward)
      - Place CTAs at the END of this section if provided (not in the middle)
    PROMPT

    client = Ai::ClientService.for_article_writing
    response = client.chat(
      messages: [{ role: "user", content: prompt }],
      max_tokens: (word_count * 2).to_i,
      temperature: 0.8
    )

    return nil unless response[:success]

    response[:content].strip
  rescue => e
    Rails.logger.error "Section #{section_index} writing failed: #{e.message}"
    nil
  end

  def write_conclusion(sections)
    conclusion_section = @outline['sections'].find { |s| s['heading']&.downcase&.include?('conclusion') }
    word_count = conclusion_section&.dig('word_count') || 200

    # Get section headings for context
    section_headings = @outline['sections']
      .reject { |s| s['heading']&.downcase&.include?('introduction') || s['heading']&.downcase&.include?('conclusion') }
      .map { |s| s['heading'] }

    prompt = <<~PROMPT
      Write a conclusion for an article about "#{@keyword}".

      ARTICLE TITLE: #{@outline['title']}

      MAIN SECTIONS COVERED:
      #{section_headings.map { |h| "- #{h}" }.join("\n")}

      KEY POINTS TO COVER:
      #{conclusion_section&.dig('key_points')&.join("\n") || "- Summarize main takeaways\n- Call to action\n- Final thought"}

      #{voice_instructions}

      TARGET: #{word_count} words

      REQUIREMENTS:
      - Start with a strong summary of the 3 MOST IMPORTANT actionable takeaways (be specific, not vague)
      - Provide ONE concrete next step readers can take immediately (not generic "take action")
      - NO vague motivational questions like "Are you ready to take the leap?"
      - NO generic calls to action like "start today"
      - Instead, give SPECIFIC actions: "Book 5 customer interviews by Friday using the script in Section 2"
      - Write in markdown format
      - DO NOT include the heading (I'll add it)
      - Avoid AI clichés like "in conclusion", "to sum up", "at the end of the day"

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
      messages: [{ role: "user", content: prompt }],
      max_tokens: (word_count * 2).to_i,
      temperature: 0.8
    )

    return nil unless response[:success]

    response[:content].strip
  rescue => e
    Rails.logger.error "Conclusion writing failed: #{e.message}"
    nil
  end

  def write_faq_section(faq_section_outline)
    faqs = @serp_data['faqs'] || []
    return nil if faqs.empty?

    heading = faq_section_outline['heading'] || "Frequently Asked Questions"
    word_count = faq_section_outline['word_count'] || 600
    questions_to_include = faq_section_outline['questions_to_include'] || []

    # Match FAQs from SERP data with questions_to_include
    selected_faqs = questions_to_include.map do |question_text|
      faqs.find { |faq| faq['question']&.downcase&.include?(question_text.downcase) || question_text.downcase.include?(faq['question']&.downcase || '') }
    end.compact

    # If outline didn't specify questions, take first 8-12 from SERP data
    selected_faqs = faqs.take(10) if selected_faqs.empty?

    faqs_text = selected_faqs.map do |faq|
      text = "**Q: #{faq['question']}**\n\n#{faq['answer']}"
      text += " ([Source](#{faq['source_url']}))" if faq['source_url'].present?
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
      messages: [{ role: "user", content: prompt }],
      max_tokens: (word_count * 2).to_i,
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

    # Sections (already include their own headings)
    sections.each do |section|
      parts << "\n#{section}\n"
    end

    # Conclusion
    parts << "\n## Conclusion\n"
    parts << "#{conclusion}\n"

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

    examples = @serp_data['detailed_examples'] || []
    used = []

    examples.each do |ex|
      company = ex['company']
      next if company.nil? || company.empty? # Skip nil/empty company names

      # Check if company name appears in text (case-insensitive)
      used << company if text =~ /#{Regexp.escape(company)}/i
    end

    used
  end

  # Extract statistics used in text
  def extract_used_statistics(text)
    return [] if text.nil? || text.empty?

    statistics = @serp_data['statistics'] || []
    used = []

    statistics.each do |stat|
      stat_text = stat['stat']
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
      @used_examples.include?(ex['company'])
    end
  end

  # Filter out statistics that have already been used
  def filter_unused_statistics(all_statistics)
    return [] if all_statistics.nil?

    all_statistics.reject do |stat|
      @used_statistics.include?(stat['stat'])
    end
  end

  # Build prompt text for visual elements
  def build_visuals_prompt(visual_elements)
    images = visual_elements['images'] || []
    videos = visual_elements['videos'] || []

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
      parts << "   Outcome: #{guide['outcome']}" if guide['outcome']
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

    parts = []
    parts << "FREE RESOURCES AVAILABLE:"

    resources.each_with_index do |resource, i|
      parts << "#{i + 1}. #{resource['title']} (#{resource['type']})"
      parts << "   #{resource['description']}"
      parts << "   URL: #{resource['url']}"
    end

    parts << ""
    parts << "RESOURCE USAGE GUIDELINES:"
    parts << "- Link to 1-2 relevant free resources when they add value"
    parts << "- Format: **[Resource Title](url)**"
    parts << "- Explain WHAT the resource is and WHY it's useful"
    parts << "- Add context: 'This Google Sheets template includes...'"
    parts << "- Use clear CTA: 'Download the [X]', 'Get the free [Y]'"
    parts << "- Only link to resources that readers can immediately use"

    parts.join("\n")
  end

  # Build prompt text for recommended tools
  def build_tools_prompt(tools)
    return "" if tools.empty?

    parts = []
    parts << "RECOMMENDED TOOLS:"

    tools.each_with_index do |tool, i|
      parts << "#{i + 1}. #{tool['tool_name']} - #{tool['category']}"
      parts << "   Use case: #{tool['use_case']}"
      parts << "   Pricing: #{tool['pricing']}"
      parts << "   Why: #{tool['why_recommended']}"
      parts << "   URL: #{tool['url']}"
    end

    parts << ""
    parts << "TOOL USAGE GUIDELINES:"
    parts << "- Mention 2-3 tools if highly relevant to this section"
    parts << "- Format: **[Tool Name](url)** - Brief description"
    parts << "- Include pricing context when relevant"
    parts << "- Explain specific use case for this topic"
    parts << "- Don't list all tools - only mention most relevant ones"

    parts.join("\n")
  end

  # Build prompt text for internal links
  def build_internal_links_prompt(internal_links)
    return "" if internal_links.empty?

    parts = []
    parts << "INTERNAL LINKS TO INCLUDE:"

    internal_links.each_with_index do |link, i|
      parts << "#{i + 1}. Link text: \"#{link['anchor_text']}\""
      parts << "   Target article: #{link['target_article_title']}"
      parts << "   Context: #{link['context']}"
    end

    parts << ""
    parts << "INTERNAL LINKING GUIDELINES:"
    parts << "- Weave internal links naturally into the text"
    parts << "- Format: [anchor text](/articles/target-slug)"
    parts << "- DON'T force links awkwardly - make them contextually relevant"
    parts << "- Place links where they provide value to the reader"
    parts << "- Example: 'For more on customer interviews, see our guide on [interview best practices](/articles/interview-guide).'"

    parts.join("\n")
  end

  # Build prompt text for CTAs
  def build_ctas_prompt(ctas)
    return "" if ctas.empty?

    parts = []
    parts << "CALL-TO-ACTION (CTA) TO INCLUDE:"

    ctas.each_with_index do |cta, i|
      parts << "#{i + 1}. CTA: \"#{cta['cta_text']}\""
      parts << "   URL: #{cta['cta_url']}"
      parts << "   Context: #{cta['context']}"
    end

    parts << ""
    parts << "CTA PLACEMENT GUIDELINES:"
    parts << "- Place CTA at the END of this section (after all content)"
    parts << "- Add brief context before CTA (why it's relevant)"
    parts << "- Format as: **[CTA Text](url)**"
    parts << "- Example: 'Ready to validate your idea? **[Start your free trial](url)** and get instant feedback.'"
    parts << "- Keep it natural and relevant to what was just discussed"

    parts.join("\n")
  end
end
