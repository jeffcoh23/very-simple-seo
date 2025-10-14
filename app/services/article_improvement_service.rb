# app/services/article_improvement_service.rb
# Improves article quality with 3 passes: fix overused companies, remove AI clichés, shorten paragraphs
class ArticleImprovementService
  # Common AI writing clichés to detect
  AI_CLICHES = [
    "in today's digital landscape",
    "in today's fast-paced world",
    "it's important to note",
    "it's worth noting",
    "in conclusion",
    "to sum up",
    "at the end of the day",
    "game-changer",
    "revolutionary",
    "unlock the power",
    "dive deep",
    "delve into",
    "leverage",
    "utilize",
    "ecosystem",
    "robust",
    "seamless",
    "cutting-edge"
  ].freeze

  def initialize(article_markdown, serp_data)
    @article_markdown = article_markdown
    @serp_data = serp_data
  end

  def perform
    Rails.logger.info "Improving article quality (3 passes)"

    # Pass 1: Fix overused companies
    improved = fix_overused_examples(@article_markdown)

    # Pass 2: Remove AI clichés
    improved = remove_ai_cliches(improved)

    # Pass 3: Shorten paragraphs
    improved = shorten_paragraphs(improved)

    Rails.logger.info "Article improved successfully"

    { data: improved, cost: 0.05 } # 3 small GPT-4o Mini calls
  end

  private

  # Pass 1: Identify overused company examples and replace with variety
  def fix_overused_examples(markdown)
    Rails.logger.info "Pass 1: Fixing overused examples"

    # Count company mentions
    examples = @serp_data['detailed_examples'] || []
    company_counts = Hash.new(0)

    examples.each do |ex|
      company = ex['company']
      company_counts[company] += markdown.scan(/#{Regexp.escape(company)}/i).size
    end

    overused = company_counts.select { |_, count| count > 3 }

    if overused.empty?
      Rails.logger.info "No overused examples found"
      return markdown
    end

    Rails.logger.info "Found overused examples: #{overused.keys.join(', ')}"

    prompt = <<~PROMPT
      This article overuses certain company examples. Replace some mentions with different examples.

      OVERUSED COMPANIES: #{overused.keys.join(', ')}

      ALTERNATIVE EXAMPLES YOU CAN USE:
      #{examples.map { |ex| "- #{ex['company']}: #{ex['what_they_did']} → #{ex['outcome']}" }.join("\n")}

      ARTICLE:
      #{markdown}

      INSTRUCTIONS:
      1. Keep the first 1-2 mentions of each overused company
      2. Replace other mentions with different examples from the list above
      3. Maintain the same point/argument, just use a different example
      4. Return the full improved article in markdown
      5. DO NOT change anything else - only swap overused examples
    PROMPT

    client = Ai::ClientService.for_article_improvement
    response = client.chat(
      messages: [{ role: "user", content: prompt }],
      max_tokens: 4000,
      temperature: 0.7
    )

    return markdown unless response[:success]

    response[:content].strip
  rescue => e
    Rails.logger.error "Pass 1 failed: #{e.message}"
    markdown # Return original on error
  end

  # Pass 2: Remove AI writing clichés
  def remove_ai_cliches(markdown)
    Rails.logger.info "Pass 2: Removing AI clichés"

    # Detect clichés
    found_cliches = AI_CLICHES.select { |cliche| markdown.downcase.include?(cliche) }

    if found_cliches.empty?
      Rails.logger.info "No AI clichés found"
      return markdown
    end

    Rails.logger.info "Found #{found_cliches.size} AI clichés"

    prompt = <<~PROMPT
      This article contains AI writing clichés. Rewrite sentences to sound more natural and human.

      CLICHÉS TO REMOVE:
      #{found_cliches.map { |c| "- \"#{c}\"" }.join("\n")}

      ARTICLE:
      #{markdown}

      INSTRUCTIONS:
      1. Find sentences containing these clichés
      2. Rewrite them to be more natural and conversational
      3. Keep the same meaning and information
      4. Don't add corporate jargon or buzzwords
      5. Return the full improved article in markdown
      6. DO NOT change anything else - only fix clichés
    PROMPT

    client = Ai::ClientService.for_article_improvement
    response = client.chat(
      messages: [{ role: "user", content: prompt }],
      max_tokens: 4000,
      temperature: 0.7
    )

    return markdown unless response[:success]

    response[:content].strip
  rescue => e
    Rails.logger.error "Pass 2 failed: #{e.message}"
    markdown # Return original on error
  end

  # Pass 3: Shorten long paragraphs for readability
  def shorten_paragraphs(markdown)
    Rails.logger.info "Pass 3: Shortening paragraphs"

    # Find paragraphs longer than 5 sentences
    long_paragraphs = []
    current_paragraph = []

    markdown.split("\n").each do |line|
      if line.strip.empty? || line.start_with?('#')
        if current_paragraph.any?
          text = current_paragraph.join(" ")
          sentence_count = text.scan(/[.!?]+/).size
          long_paragraphs << text if sentence_count > 5
          current_paragraph = []
        end
      else
        current_paragraph << line unless line.start_with?('#')
      end
    end

    if long_paragraphs.empty?
      Rails.logger.info "No long paragraphs found"
      return markdown
    end

    Rails.logger.info "Found #{long_paragraphs.size} long paragraphs"

    prompt = <<~PROMPT
      This article has paragraphs that are too long. Break them into shorter, more readable chunks.

      ARTICLE:
      #{markdown}

      INSTRUCTIONS:
      1. Find paragraphs with more than 4-5 sentences
      2. Break them into 2-3 smaller paragraphs
      3. Each paragraph should be 2-4 sentences max
      4. Maintain logical flow and coherence
      5. Don't change the content, just the paragraph structure
      6. Return the full improved article in markdown
      7. Keep all headings, lists, and formatting intact
    PROMPT

    client = Ai::ClientService.for_article_improvement
    response = client.chat(
      messages: [{ role: "user", content: prompt }],
      max_tokens: 4000,
      temperature: 0.7
    )

    return markdown unless response[:success]

    response[:content].strip
  rescue => e
    Rails.logger.error "Pass 3 failed: #{e.message}"
    markdown # Return original on error
  end
end
