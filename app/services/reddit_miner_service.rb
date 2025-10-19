# app/services/reddit_miner_service.rb
# Mines Reddit for keyword opportunities from user discussions
class RedditMinerService
  USER_AGENT = "Mozilla/5.0 (compatible; VerySimpleSEO/1.0)"

  def initialize(keyword)
    @keyword = keyword
  end

  def mine
    Rails.logger.info "Mining Reddit for: #{@keyword}"

    begin
      # Reddit search API (free, no auth required)
      query = URI.encode_www_form_component(@keyword)
      uri = URI("https://www.reddit.com/search.json?q=#{query}&limit=50&sort=relevance")

      request = Net::HTTP::Get.new(uri)
      request["User-Agent"] = USER_AGENT

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 10) do |http|
        http.request(request)
      end

      data = JSON.parse(response.body)

      # Extract post titles
      titles = data.dig("data", "children")&.map { |post| post.dig("data", "title") } || []

      # Extract keywords from titles (questions and phrases)
      keywords = titles.flat_map do |title|
        extract_keywords_from_text(title)
      end

      keywords = keywords.compact.uniq.reject(&:empty?)

      Rails.logger.info "Found #{keywords.size} keywords from Reddit" if keywords.any?
      keywords
    rescue => e
      Rails.logger.error "Reddit mining failed: #{e.message}"
      []
    end
  end

  private

  def extract_keywords_from_text(text)
    return [] if text.nil? || text.empty?

    keywords = []
    text = text.downcase

    # Extract question-based keywords
    if text.include?("how to")
      keywords << text[/how to [^?.!]+/]
    end

    if text.include?("what is")
      keywords << text[/what is [^?.!]+/]
    end

    if text.include?("best way")
      keywords << text[/best way [^?.!]+/]
    end

    if text.include?("how do i")
      keywords << text[/how do i [^?.!]+/]
    end

    if text.include?("should i")
      keywords << text[/should i [^?.!]+/]
    end

    # Extract phrases containing the current seed keyword
    if text.include?(@keyword.downcase)
      # Extract 5 words before and after
      match = text[/.{0,50}#{Regexp.escape(@keyword.downcase)}.{0,50}/]
      keywords << match if match
    end

    keywords.compact.map(&:strip)
  end
end
