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

    # Write each section
    sections = []
    @outline['sections'].each_with_index do |section_outline, i|
      next if section_outline['heading']&.downcase&.include?('introduction')
      next if section_outline['heading']&.downcase&.include?('conclusion')

      Rails.logger.info "Writing section #{i + 1}/#{@outline['sections'].size}: #{section_outline['heading']}"

      section_content = write_section(section_outline, i)
      sections << section_content if section_content
    end

    # Write conclusion
    conclusion = write_conclusion
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
      #{examples.take(3).map { |ex| "- #{ex['company']}: #{ex['what_they_did']} → #{ex['outcome']}" }.join("\n")}

      AVAILABLE STATISTICS (use 1-2 if relevant):
      #{statistics.take(3).map { |stat| "- #{stat['stat']} (#{stat['source']})" }.join("\n")}

      #{voice_instructions}

      TARGET: #{word_count} words

      REQUIREMENTS:
      - Hook reader in first sentence
      - Use a real example or statistic to establish credibility
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

  def write_section(section_outline, section_index)
    examples = @serp_data['detailed_examples'] || []
    statistics = @serp_data['statistics'] || []

    heading = section_outline['heading']
    word_count = section_outline['word_count'] || 400
    key_points = section_outline['key_points'] || []
    subsections = section_outline['subsections'] || []

    prompt = <<~PROMPT
      Write a section for an article about "#{@keyword}".

      SECTION HEADING: #{heading}

      KEY POINTS TO COVER:
      #{key_points.map { |p| "- #{p}" }.join("\n")}

      #{subsections.any? ? "SUBSECTIONS TO INCLUDE:\n#{subsections.map { |s| "- #{s['heading']}: #{s['key_points']&.join(', ')}" }.join("\n")}" : ""}

      AVAILABLE EXAMPLES (use 2-3 if relevant):
      #{examples.take(5).map { |ex| "- #{ex['company']}: #{ex['what_they_did']} → #{ex['outcome']}" }.join("\n")}

      AVAILABLE STATISTICS (use 2-3 if relevant):
      #{statistics.take(5).map { |stat| "- #{stat['stat']} (#{stat['source']})" }.join("\n")}

      #{voice_instructions}

      TARGET: #{word_count} words

      REQUIREMENTS:
      - Write in markdown format
      - Include the H2 heading: ## #{heading}
      - Use H3 headings (###) for subsections
      - Use real examples and statistics from the data provided
      - Include bullet points or numbered lists where appropriate
      - Keep paragraphs short (2-4 sentences)
      - Use natural, conversational tone
      - Avoid AI clichés like "it's important to note" or "remember"
      - Make it actionable and specific
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

  def write_conclusion
    conclusion_section = @outline['sections'].find { |s| s['heading']&.downcase&.include?('conclusion') }
    word_count = conclusion_section&.dig('word_count') || 200

    prompt = <<~PROMPT
      Write a conclusion for an article about "#{@keyword}".

      ARTICLE TITLE: #{@outline['title']}

      KEY POINTS TO COVER:
      #{conclusion_section&.dig('key_points')&.join("\n") || "- Summarize main takeaways\n- Call to action\n- Final thought"}

      #{voice_instructions}

      TARGET: #{word_count} words

      REQUIREMENTS:
      - Summarize the main insights without being repetitive
      - Give readers a clear next step
      - End with a thought-provoking question or statement
      - Write in markdown format
      - DO NOT include the heading (I'll add it)
      - Avoid AI clichés like "in conclusion" or "to sum up"
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
end
