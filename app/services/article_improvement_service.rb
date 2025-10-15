# app/services/article_improvement_service.rb
# Improves article quality with 5 passes: fix overused examples/stats, remove AI clichés, shorten paragraphs, add depth
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

  # Shallow/generic advice patterns to detect
  SHALLOW_PATTERNS = [
    /create user personas/i,
    /conduct surveys/i,
    /analyze competitors/i,
    /use social media/i,
    /do market research/i,
    /talk to customers/i,
    /build an mvp/i,
    /test your idea/i,
    /validate your concept/i,
    /get feedback/i
  ].freeze

  def initialize(article_markdown, serp_data)
    @article_markdown = article_markdown
    @serp_data = serp_data
  end

  def perform
    Rails.logger.info "Improving article quality (5 passes)"

    # Pass 1: Fix overused examples
    improved = fix_overused_examples(@article_markdown)

    # Pass 2: Fix overused statistics (NEW)
    improved = fix_overused_statistics(improved)

    # Pass 3: Remove AI clichés
    improved = remove_ai_cliches(improved)

    # Pass 4: Shorten paragraphs
    improved = shorten_paragraphs(improved)

    # Pass 5: Add depth to shallow content (NEW)
    improved = add_tactical_depth(improved)

    Rails.logger.info "Article improved successfully"

    { data: improved, cost: 0.08 } # 5 small GPT-4o Mini calls
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

    overused = company_counts.select { |_, count| count > 1 }

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

  # Pass 2: Fix overused statistics (NEW)
  def fix_overused_statistics(markdown)
    Rails.logger.info "Pass 2: Fixing overused statistics"

    # Count statistic mentions
    statistics = @serp_data['statistics'] || []
    stat_counts = Hash.new(0)

    statistics.each do |stat|
      stat_text = stat['stat']
      # Count how many times this exact stat appears
      stat_counts[stat_text] += markdown.scan(/#{Regexp.escape(stat_text)}/i).size
    end

    overused = stat_counts.select { |_, count| count > 1 }

    if overused.empty?
      Rails.logger.info "No overused statistics found"
      return markdown
    end

    Rails.logger.info "Found overused statistics: #{overused.keys.take(3).join(', ')}"

    prompt = <<~PROMPT
      This article repeats certain statistics multiple times. Keep only the FIRST mention of each stat.

      OVERUSED STATISTICS:
      #{overused.keys.map { |s| "- #{s}" }.join("\n")}

      ARTICLE:
      #{markdown}

      INSTRUCTIONS:
      1. For each statistic above, keep ONLY the first mention
      2. Remove all subsequent mentions of the same statistic
      3. If a stat is used in multiple contexts, keep the most impactful first use
      4. Return the full improved article in markdown
      5. DO NOT change anything else - only remove duplicate statistics
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

  # Pass 4: Shorten long paragraphs for readability
  def shorten_paragraphs(markdown)
    Rails.logger.info "Pass 4: Shortening paragraphs"

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
    Rails.logger.error "Pass 4 failed: #{e.message}"
    markdown # Return original on error
  end

  # Pass 5: Add tactical depth to shallow content (NEW)
  def add_tactical_depth(markdown)
    Rails.logger.info "Pass 5: Adding tactical depth"

    # Check for shallow patterns
    shallow_found = SHALLOW_PATTERNS.any? { |pattern| markdown =~ pattern }

    unless shallow_found
      Rails.logger.info "No shallow content detected"
      return markdown
    end

    Rails.logger.info "Found shallow/generic advice, adding tactical depth"

    prompt = <<~PROMPT
      This article contains generic advice that lacks tactical depth. Transform it into actionable how-to content.

      ARTICLE:
      #{markdown}

      INSTRUCTIONS:
      For every generic statement like "conduct surveys" or "create user personas", ADD tactical details:

      BEFORE: "Conduct customer interviews to validate your idea."
      AFTER: "Conduct customer interviews to validate your idea. Book 10-15 interviews using these steps:
      1. Find participants on LinkedIn by searching '[your niche] professional'
      2. Send this cold outreach: 'Hi [name], I'm researching [problem]. Can I ask 3 quick questions? Takes 10 min.'
      3. Use this interview script:
         - 'Tell me about the last time you experienced [problem]...'
         - 'What did you try to solve it?'
         - 'If I could solve this perfectly, what would that look like?'
         - 'Would you pay $X/month for that solution?'"

      Add:
      - SPECIFIC steps (numbered lists, actual scripts)
      - CONCRETE tools/platforms (SurveyMonkey, Typeform, LinkedIn)
      - QUANTITATIVE guidance (10-15 interviews, 30+ signups, $X budget)
      - EXAMPLE questions, templates, or frameworks

      Return the full improved article with added tactical depth.
      Keep everything else the same - only expand generic advice into detailed how-tos.
    PROMPT

    client = Ai::ClientService.for_article_improvement
    response = client.chat(
      messages: [{ role: "user", content: prompt }],
      max_tokens: 5000, # Higher token limit for expansion
      temperature: 0.7
    )

    return markdown unless response[:success]

    response[:content].strip
  rescue => e
    Rails.logger.error "Pass 5 failed: #{e.message}"
    markdown # Return original on error
  end
end
