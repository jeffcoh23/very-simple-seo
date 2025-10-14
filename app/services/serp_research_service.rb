# app/services/serp_research_service.rb
# Researches Google SERP results, scrapes article content, and analyzes with AI
class SerpResearchService
  USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"

  def initialize(keyword)
    @keyword = keyword
  end

  def perform
    Rails.logger.info "Starting SERP research for: #{@keyword}"

    # Step 1: Fetch Google search results via Custom Search API
    search_results = scrape_google

    if search_results.empty?
      Rails.logger.error "No search results found for: #{@keyword}"
      return { data: nil, cost: 0 }
    end

    Rails.logger.info "Found #{search_results.size} Google results"

    # Step 2: Scrape article content from top 10 results
    top_articles = fetch_article_content(search_results.take(10))
    Rails.logger.info "Successfully fetched #{top_articles.size} articles"

    # Step 3: Analyze in batches (Gemini output limit)
    all_examples = []
    all_stats = []

    top_articles.each_slice(3).with_index do |batch, i|
      result = analyze_article_batch(batch, i + 1)
      all_examples.concat(result[:examples] || [])
      all_stats.concat(result[:stats] || [])
    end

    Rails.logger.info "Extracted #{all_examples.size} examples and #{all_stats.size} statistics"

    # Step 4: Final analysis for topics and gaps
    final_analysis = analyze_serp_results(search_results, top_articles, all_examples, all_stats)

    if final_analysis.nil?
      Rails.logger.error "SERP analysis failed"
      return { data: nil, cost: 0.20 }
    end

    # Add examples and stats to the data
    final_analysis['detailed_examples'] = all_examples
    final_analysis['statistics'] = all_stats

    Rails.logger.info "SERP research complete"

    { data: final_analysis, cost: 0.20 } # Gemini analysis with batching (~5 calls for 10 articles)
  end

  # Public method for getting search results only (used by AutofillProjectService)
  def search_results_only
    scrape_google
  end

  private

  def scrape_google
    api_key = ENV['GOOGLE_SEARCH_KEY']
    cx = ENV['GOOGLE_SEARCH_CX'] || '017576662512468239146:omuauf_lfve'

    if api_key.blank?
      Rails.logger.error "GOOGLE_SEARCH_KEY not configured"
      return []
    end

    query = URI.encode_www_form_component(@keyword)
    url = "https://www.googleapis.com/customsearch/v1?key=#{api_key}&cx=#{cx}&q=#{query}&num=10"

    uri = URI(url)
    response = Net::HTTP.get_response(uri)

    unless response.code == '200'
      Rails.logger.error "Google API error: #{response.code}"
      return []
    end

    data = JSON.parse(response.body)

    if data['error']
      Rails.logger.error "Google API error: #{data['error']['message']}"
      return []
    end

    results = []
    (data['items'] || []).each do |item|
      results << {
        title: item['title'],
        url: item['link'],
        snippet: item['snippet'] || ""
      }
      break if results.size >= 10
    end

    results
  rescue => e
    Rails.logger.error "Google API failed: #{e.message}"
    []
  end

  def fetch_article_content(urls)
    articles = []

    urls.each_with_index do |result, i|
      begin
        Rails.logger.info "Fetching article #{i+1}/#{urls.size}"

        uri = URI(result[:url])
        response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https',
                                   open_timeout: 5, read_timeout: 10) do |http|
          request = Net::HTTP::Get.new(uri)
          request["User-Agent"] = USER_AGENT
          http.request(request)
        end

        next unless response.code == '200'

        doc = Nokogiri::HTML(response.body)

        # Remove scripts, styles, nav, footer
        doc.css('script, style, nav, footer, header, aside, iframe').remove

        # Try to find main content
        main_content = doc.at_css('article') || doc.at_css('main') || doc.at_css('[role="main"]') || doc.at_css('body')

        # Extract text
        text = main_content.text.gsub(/\s+/, ' ').strip

        articles << {
          url: result[:url],
          title: result[:title],
          content: text,
          word_count: text.split.size
        }

      rescue => e
        Rails.logger.warn "Failed to fetch #{result[:url]}: #{e.message}"
        next
      end
    end

    articles
  end

  def analyze_article_batch(articles, batch_num)
    Rails.logger.info "Analyzing batch #{batch_num} (#{articles.size} articles)"

    prompt = <<~PROMPT
      Extract examples and statistics from these articles:

      #{articles.map.with_index do |article, i|
        content_preview = article[:content][0..5000]
        "=== ARTICLE: #{article[:title]} (#{article[:word_count]} words) ===\n#{content_preview}\n\n"
      end.join("\n")}

      IMPORTANT: Extract ALL examples and statistics you find.

      Format your response as JSON:
      {
        "examples": [
          {
            "company": "Dropbox",
            "what_they_did": "created a demo video to validate their idea",
            "outcome": "got 75,000 signups overnight",
            "relevance": "MVP validation"
          }
        ],
        "stats": [
          {
            "stat": "42% of startups fail due to no market need",
            "source": "CB Insights",
            "context": "why validation matters"
          }
        ]
      }

      Extract every example and statistic you can find.
    PROMPT

    client = Ai::ClientService.for_serp_analysis
    response = client.chat(
      messages: [{ role: "user", content: prompt }],
      max_tokens: 8000,
      temperature: 0.7
    )

    return { examples: [], stats: [] } unless response[:success]

    json_str = extract_json(response[:content])
    return { examples: [], stats: [] } if json_str.nil?

    data = JSON.parse(json_str)
    { examples: data['examples'] || [], stats: data['stats'] || [] }
  rescue => e
    Rails.logger.error "Batch #{batch_num} failed: #{e.message}"
    { examples: [], stats: [] }
  end

  def analyze_serp_results(search_results, top_articles, all_examples, all_stats)
    prompt = <<~PROMPT
      Analyze these top Google search results for "#{@keyword}":

      #{search_results.map.with_index do |result, i|
        "#{i+1}. #{result[:title]}\n   URL: #{result[:url]}\n   Snippet: #{result[:snippet]}\n"
      end.join("\n")}

      EXTRACTED EXAMPLES FROM ARTICLES:
      #{all_examples.map { |ex| "- #{ex['company']}: #{ex['what_they_did']} → #{ex['outcome']}" }.join("\n")}

      EXTRACTED STATISTICS FROM ARTICLES:
      #{all_stats.map { |stat| "- #{stat['stat']} (#{stat['source']})" }.join("\n")}

      Based on the search results and extracted data, analyze:

      Format your response as JSON:
      {
        "common_topics": ["topics that appear in multiple articles based on titles/snippets"],
        "content_gaps": ["topics that could be covered but aren't mentioned"],
        "average_word_count": #{top_articles.any? ? (top_articles.map { |a| a[:word_count] }.sum.to_f / top_articles.size).to_i : 2000},
        "recommended_approach": "how to beat these results with better content"
      }
    PROMPT

    client = Ai::ClientService.for_serp_analysis
    response = client.chat(
      messages: [{ role: "user", content: prompt }],
      max_tokens: 4000,
      temperature: 0.7
    )

    return nil unless response[:success]

    json_str = extract_json(response[:content])
    return nil if json_str.nil?

    JSON.parse(json_str)
  rescue => e
    Rails.logger.error "SERP analysis failed: #{e.message}"
    nil
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
