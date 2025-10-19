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

    # Step 4: Extract visual elements, tables, guides, and resources
    visual_elements = extract_visual_elements(top_articles)
    comparison_tables = extract_comparison_tables(top_articles)
    step_by_step_guides = extract_step_by_step_guides(top_articles)
    downloadable_resources = extract_downloadable_resources(top_articles)

    Rails.logger.info "Extracted #{visual_elements['images']&.size || 0} images, #{visual_elements['videos']&.size || 0} videos"
    Rails.logger.info "Extracted #{comparison_tables['tables']&.size || 0} tables, #{step_by_step_guides['guides']&.size || 0} guides"
    Rails.logger.info "Extracted #{downloadable_resources['resources']&.size || 0} resources"

    # Step 5: Final analysis for topics and gaps
    final_analysis = analyze_serp_results(search_results, top_articles, all_examples, all_stats)

    if final_analysis.nil?
      Rails.logger.error "SERP analysis failed"
      return { data: nil, cost: 0.24 } # 4 extra AI calls
    end

    # Add all extracted data
    final_analysis["detailed_examples"] = all_examples
    final_analysis["statistics"] = all_stats
    final_analysis["visual_elements"] = visual_elements
    final_analysis["comparison_tables"] = comparison_tables
    final_analysis["step_by_step_guides"] = step_by_step_guides
    final_analysis["downloadable_resources"] = downloadable_resources

    Rails.logger.info "SERP research complete"

    { data: final_analysis, cost: 0.24 } # Gemini analysis with batching (~9 calls total)
  end

  # Public method for getting search results only (used by AutofillProjectService)
  def search_results_only
    scrape_google
  end

  private

  def scrape_google
    api_key = ENV["GOOGLE_SEARCH_KEY"]
    cx = ENV["GOOGLE_SEARCH_CX"] || "017576662512468239146:omuauf_lfve"

    if api_key.blank?
      Rails.logger.error "GOOGLE_SEARCH_KEY not configured"
      return []
    end

    query = URI.encode_www_form_component(@keyword)
    results = []

    # Fetch 2 pages (20 results total) for better competitor coverage
    # Google Custom Search API max is 10 per request
    [ 1, 11 ].each do |start_index|
      url = "https://www.googleapis.com/customsearch/v1?key=#{api_key}&cx=#{cx}&q=#{query}&num=10&start=#{start_index}"

      uri = URI(url)
      response = Net::HTTP.get_response(uri)

      unless response.code == "200"
        Rails.logger.error "Google API error: #{response.code}"
        next
      end

      data = JSON.parse(response.body)

      if data["error"]
        Rails.logger.error "Google API error: #{data['error']['message']}"
        next
      end

      (data["items"] || []).each do |item|
        results << {
          title: item["title"],
          url: item["link"],
          snippet: item["snippet"] || ""
        }
      end

      # Small delay between API calls
      sleep 0.5 if start_index == 1
    end

    Rails.logger.info "Fetched #{results.size} search results from Google"
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
        response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https",
                                   open_timeout: 5, read_timeout: 10) do |http|
          request = Net::HTTP::Get.new(uri)
          request["User-Agent"] = USER_AGENT
          http.request(request)
        end

        next unless response.code == "200"

        doc = Nokogiri::HTML(response.body)

        # Remove scripts, styles, nav, footer
        doc.css("script, style, nav, footer, header, aside, iframe").remove

        # Try to find main content
        main_content = doc.at_css("article") || doc.at_css("main") || doc.at_css('[role="main"]') || doc.at_css("body")

        # Extract text
        text = main_content.text.gsub(/\s+/, " ").strip

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
            "how_they_did_it": "Posted 3-minute explainer video on Hacker News with waitlist link, no code written yet",
            "outcome": "got 75,000 signups overnight",
            "timeline": "2008, before building the product",
            "relevance": "MVP validation"
          }
        ],
        "stats": [
          {
            "stat": "42% of startups fail due to no market need",
            "source": "CB Insights",
            "source_url": "https://www.cbinsights.com/research/startup-failure-reasons-top/",
            "context": "why validation matters"
          }
        ]
      }

      IMPORTANT INSTRUCTIONS:

      For EXAMPLES:
      - Extract not just WHAT they did, but HOW they did it (specific steps, tools, channels)
      - Include WHEN/timeline if mentioned (e.g., "2008, before product launch")
      - Be specific: "Posted on Hacker News" not just "shared online"
      - If HOW details aren't in the text, leave "how_they_did_it" as empty string

      For STATISTICS:
      - Try to extract the source URL where the stat was found or referenced
      - If no URL is available in the text, leave source_url as empty string

      Extract every example and statistic you can find with maximum tactical detail.
    PROMPT

    client = Ai::ClientService.for_serp_analysis
    response = client.chat(
      messages: [ { role: "user", content: prompt } ],
      max_tokens: 8000,
      temperature: 0.7
    )

    return { examples: [], stats: [] } unless response[:success]

    json_str = extract_json(response[:content])
    return { examples: [], stats: [] } if json_str.nil?

    data = JSON.parse(json_str)
    { examples: data["examples"] || [], stats: data["stats"] || [] }
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
      messages: [ { role: "user", content: prompt } ],
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

  def extract_visual_elements(articles)
    Rails.logger.info "Extracting visual elements from articles"

    # Collect all image and video URLs from scraped HTML
    all_images = []
    all_videos = []

    articles.each do |article|
      begin
        # Re-fetch to get full HTML with images/videos
        uri = URI(article[:url])
        response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https",
                                   open_timeout: 5, read_timeout: 10) do |http|
          request = Net::HTTP::Get.new(uri)
          request["User-Agent"] = USER_AGENT
          http.request(request)
        end

        next unless response.code == "200"

        doc = Nokogiri::HTML(response.body)

        # Extract images (skip tiny logos/icons)
        doc.css("img").each do |img|
          src = img["src"]
          alt = img["alt"] || ""
          next if src.nil? || src.empty?

          # Skip small images (likely logos)
          width = img["width"].to_i
          height = img["height"].to_i
          next if width > 0 && width < 200

          all_images << {
            url: src.start_with?("http") ? src : URI.join(article[:url], src).to_s,
            alt: alt,
            context: img.parent.text[0..100]
          }
        end

        # Extract YouTube/Vimeo embeds
        doc.css("iframe").each do |iframe|
          src = iframe["src"] || ""
          next unless src.include?("youtube") || src.include?("vimeo")

          all_videos << {
            url: src.start_with?("http") ? src : URI.join(article[:url], src).to_s,
            title: iframe["title"] || ""
          }
        end
      rescue => e
        Rails.logger.warn "Failed to extract visuals from #{article[:url]}: #{e.message}"
      end
    end

    # Deduplicate
    all_images = all_images.uniq { |img| img[:url] }
    all_videos = all_videos.uniq { |vid| vid[:url] }

    Rails.logger.info "Found #{all_images.size} images and #{all_videos.size} videos"

    return { "images" => [], "videos" => [] } if all_images.empty? && all_videos.empty?

    # AI filters for relevance
    filter_relevant_visuals(all_images, all_videos)
  rescue => e
    Rails.logger.error "Visual extraction failed: #{e.message}"
    { "images" => [], "videos" => [] }
  end

  def filter_relevant_visuals(images, videos)
    prompt = <<~PROMPT
      Topic: "#{@keyword}"

      From these visuals found in top 10 articles, select the MOST relevant:

      IMAGES (#{images.size} found):
      #{images.take(20).map { |i| "- #{i[:url]} (alt: #{i[:alt]})" }.join("\n")}

      VIDEOS (#{videos.size} found):
      #{videos.map { |v| "- #{v[:url]} (#{v[:title]})" }.join("\n")}

      Return JSON with:
      1. Top 3-5 most relevant images (screenshots, diagrams, charts - NOT stock photos or author headshots)
      2. Top 1-2 most relevant tutorial videos
      3. Brief description of what each visual shows

      {
        "images": [
          {"url": "...", "description": "Screenshot showing X feature"},
          {"url": "...", "description": "Diagram comparing Y vs Z"}
        ],
        "videos": [
          {"url": "youtube.com/...", "description": "Tutorial on setting up X"}
        ]
      }

      IGNORE:
      - Stock photos
      - Author headshots
      - Logos
      - Ads
    PROMPT

    client = Ai::ClientService.for_serp_analysis
    response = client.chat(
      messages: [ { role: "user", content: prompt } ],
      max_tokens: 2000,
      temperature: 0.7
    )

    return { "images" => [], "videos" => [] } unless response[:success]

    json_str = extract_json(response[:content])
    return { "images" => [], "videos" => [] } if json_str.nil?

    JSON.parse(json_str)
  rescue => e
    Rails.logger.error "Visual filtering failed: #{e.message}"
    { "images" => [], "videos" => [] }
  end

  def extract_comparison_tables(articles)
    Rails.logger.info "Extracting comparison tables from articles"

    all_tables = []

    articles.each do |article|
      begin
        # Re-fetch to get full HTML
        uri = URI(article[:url])
        response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https",
                                   open_timeout: 5, read_timeout: 10) do |http|
          request = Net::HTTP::Get.new(uri)
          request["User-Agent"] = USER_AGENT
          http.request(request)
        end

        next unless response.code == "200"

        doc = Nokogiri::HTML(response.body)

        # Find HTML tables
        doc.css("table").each do |table|
          headers = table.css("th").map(&:text).map(&:strip)
          rows = table.css("tr").map { |tr| tr.css("td").map(&:text).map(&:strip) }.reject(&:empty?)

          next if headers.empty? || rows.size < 2

          all_tables << {
            headers: headers,
            rows: rows,
            context: table.previous_element&.text || ""
          }
        end
      rescue => e
        Rails.logger.warn "Failed to extract tables from #{article[:url]}: #{e.message}"
      end
    end

    Rails.logger.info "Found #{all_tables.size} tables"

    return { "tables" => [] } if all_tables.empty?

    # AI structures the tables
    structure_tables(all_tables)
  rescue => e
    Rails.logger.error "Table extraction failed: #{e.message}"
    { "tables" => [] }
  end

  def structure_tables(raw_tables)
    prompt = <<~PROMPT
      Topic: "#{@keyword}"

      From these tables found in competitor articles, extract the MOST useful ones:

      #{raw_tables.take(10).map.with_index { |t, i|
        "TABLE #{i+1} (Context: #{t[:context][0..100]})\nHeaders: #{t[:headers].join(' | ')}\nRows:\n#{t[:rows].take(5).map { |r| r.join(' | ') }.join("\n")}"
      }.join("\n\n")}

      Return JSON with:
      1. Top 2-3 most useful comparison tables
      2. Clean headers and data
      3. Title for each table

      {
        "tables": [
          {
            "title": "SEO vs SEM: Cost Comparison",
            "headers": ["Metric", "SEO", "SEM"],
            "rows": [
              ["Time to results", "3-6 months", "Immediate"],
              ["Cost", "$500-2000/mo", "$1000-10000/mo"]
            ]
          }
        ]
      }

      IGNORE:
      - Navigation tables
      - Footer tables
      - Tables with only 1-2 rows
    PROMPT

    client = Ai::ClientService.for_serp_analysis
    response = client.chat(
      messages: [ { role: "user", content: prompt } ],
      max_tokens: 3000,
      temperature: 0.7
    )

    return { "tables" => [] } unless response[:success]

    json_str = extract_json(response[:content])
    return { "tables" => [] } if json_str.nil?

    JSON.parse(json_str)
  rescue => e
    Rails.logger.error "Table structuring failed: #{e.message}"
    { "tables" => [] }
  end

  def extract_step_by_step_guides(articles)
    Rails.logger.info "Extracting step-by-step guides from articles"

    all_guides = []

    articles.each do |article|
      begin
        # Re-fetch to get full HTML with list structure
        uri = URI(article[:url])
        response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https",
                                   open_timeout: 5, read_timeout: 10) do |http|
          request = Net::HTTP::Get.new(uri)
          request["User-Agent"] = USER_AGENT
          http.request(request)
        end

        next unless response.code == "200"

        doc = Nokogiri::HTML(response.body)

        # Find ordered/unordered lists with 3+ items
        (doc.css("ol") + doc.css("ul")).each do |list|
          items = list.css("li").map(&:text).map(&:strip)
          next if items.size < 3

          all_guides << {
            heading: list.previous_element&.text || "",
            steps: items,
            context: list.parent.text[0..200]
          }
        end
      rescue => e
        Rails.logger.warn "Failed to extract guides from #{article[:url]}: #{e.message}"
      end
    end

    Rails.logger.info "Found #{all_guides.size} potential guides"

    return { "guides" => [] } if all_guides.empty?

    # AI filters for actionable guides
    extract_actionable_guides(all_guides)
  rescue => e
    Rails.logger.error "Guide extraction failed: #{e.message}"
    { "guides" => [] }
  end

  def extract_actionable_guides(raw_guides)
    prompt = <<~PROMPT
      Topic: "#{@keyword}"

      From these lists, extract ACTIONABLE step-by-step guides (not fluffy lists):

      #{raw_guides.take(15).map.with_index { |g, i|
        "GUIDE #{i+1}: #{g[:heading]}\n#{g[:steps].take(10).map.with_index { |s, j| "#{j+1}. #{s[0..150]}" }.join("\n")}"
      }.join("\n\n")}

      Return JSON with:
      1. Top 3-5 most actionable guides
      2. Rewrite steps to be SPECIFIC (tools, timelines, exact actions)
      3. Add context for each guide

      IGNORE:
      - Generic lists like "1. Plan 2. Execute 3. Measure"
      - Motivational lists like "1. Believe in yourself"
      - Navigation lists

      KEEP:
      - Tactical guides with specific tools/actions
      - Step-by-step processes with clear outcomes
      - Implementation timelines

      {
        "guides": [
          {
            "title": "How to Launch a Referral Program in 1 Week",
            "steps": [
              "Day 1-2: Design dual incentive (give X to referrer AND referee)",
              "Day 3-4: Build tracking with unique codes (use Rewardful or ReferralCandy)",
              "Day 5: Add 'Invite' button to product UI (top nav or settings page)",
              "Day 6-7: Email existing users with early access + 2x bonus"
            ],
            "outcome": "100+ referrals in first month"
          }
        ]
      }
    PROMPT

    client = Ai::ClientService.for_serp_analysis
    response = client.chat(
      messages: [ { role: "user", content: prompt } ],
      max_tokens: 4000,
      temperature: 0.7
    )

    return { "guides" => [] } unless response[:success]

    json_str = extract_json(response[:content])
    return { "guides" => [] } if json_str.nil?

    JSON.parse(json_str)
  rescue => e
    Rails.logger.error "Guide filtering failed: #{e.message}"
    { "guides" => [] }
  end

  def extract_downloadable_resources(articles)
    Rails.logger.info "Extracting downloadable resources from articles"

    all_resources = []

    articles.each do |article|
      begin
        # Re-fetch to get full HTML with links
        uri = URI(article[:url])
        response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https",
                                   open_timeout: 5, read_timeout: 10) do |http|
          request = Net::HTTP::Get.new(uri)
          request["User-Agent"] = USER_AGENT
          http.request(request)
        end

        next unless response.code == "200"

        doc = Nokogiri::HTML(response.body)

        # Find links to templates, tools, calculators
        doc.css("a[href]").each do |link|
          text = link.text.downcase
          href = link["href"] || ""

          # Match template/tool keywords
          is_resource = text.include?("template") || text.include?("download") ||
                       text.include?("free") || text.include?("calculator") ||
                       href.include?("template") || href.include?(".pdf") ||
                       href.include?("notion.so") || href.include?("docs.google.com") ||
                       href.include?("airtable.com") || href.include?("sheets")

          next unless is_resource

          resource_url = href.start_with?("http") ? href : URI.join(article[:url], href).to_s rescue nil
          next if resource_url.nil?

          all_resources << {
            title: link.text.strip,
            url: resource_url,
            type: detect_resource_type(resource_url)
          }
        end
      rescue => e
        Rails.logger.warn "Failed to extract resources from #{article[:url]}: #{e.message}"
      end
    end

    # Deduplicate
    all_resources = all_resources.uniq { |r| r[:url] }

    Rails.logger.info "Found #{all_resources.size} potential resources"

    return { "resources" => [] } if all_resources.empty?

    # AI filters for legitimate resources
    filter_legitimate_resources(all_resources)
  rescue => e
    Rails.logger.error "Resource extraction failed: #{e.message}"
    { "resources" => [] }
  end

  def detect_resource_type(url)
    return "pdf" if url.include?(".pdf")
    return "notion" if url.include?("notion.so")
    return "spreadsheet" if url.include?("docs.google.com") || url.include?("sheets") || url.include?("airtable.com")
    return "tool" if url.include?("ahrefs") || url.include?("semrush") || url.include?("moz")
    "other"
  end

  def filter_legitimate_resources(raw_resources)
    prompt = <<~PROMPT
      Topic: "#{@keyword}"

      From these downloadable resources, select LEGITIMATE free tools/templates:

      #{raw_resources.take(20).map.with_index { |r, i|
        "#{i+1}. #{r[:title]} (#{r[:type]}) - #{r[:url]}"
      }.join("\n")}

      Return JSON with:
      1. Top 3-5 most useful FREE resources
      2. Clean up titles
      3. Brief description of what each provides

      IGNORE:
      - Paid products disguised as "free"
      - Gated resources requiring signup to download
      - Broken/spam links
      - Self-promotional links that aren't actual resources

      {
        "resources": [
          {
            "title": "SEO Audit Checklist (Google Sheets)",
            "url": "docs.google.com/...",
            "type": "spreadsheet",
            "description": "100-point checklist covering technical SEO, content, and backlinks"
          },
          {
            "title": "Keyword Research Notion Template",
            "url": "notion.so/...",
            "type": "notion",
            "description": "Pre-built database to track keywords, volume, difficulty, and content ideas"
          }
        ]
      }
    PROMPT

    client = Ai::ClientService.for_serp_analysis
    response = client.chat(
      messages: [ { role: "user", content: prompt } ],
      max_tokens: 2000,
      temperature: 0.7
    )

    return { "resources" => [] } unless response[:success]

    json_str = extract_json(response[:content])
    return { "resources" => [] } if json_str.nil?

    JSON.parse(json_str)
  rescue => e
    Rails.logger.error "Resource filtering failed: #{e.message}"
    { "resources" => [] }
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
