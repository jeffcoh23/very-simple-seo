# app/services/serp_scraper_service.rb
# Scrapes Google SERP for People Also Ask and Related Searches
class SerpScraperService
  USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"

  def initialize(keyword)
    @keyword = keyword
  end

  def scrape_people_also_ask
    Rails.logger.info "Scraping People Also Ask for: #{@keyword}"

    begin
      uri = URI("https://www.google.com/search?q=#{URI.encode_www_form_component(@keyword)}")
      request = Net::HTTP::Get.new(uri)
      request["User-Agent"] = USER_AGENT

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 10) do |http|
        http.request(request)
      end

      doc = Nokogiri::HTML(response.body)

      # Extract PAA questions (Google's structure changes, so try multiple selectors)
      paa_questions = []

      # Try common PAA selectors
      paa_questions += doc.css('[jsname="yEVEE"]').map(&:text)
      paa_questions += doc.css('.related-question-pair span').map(&:text)
      paa_questions += doc.css('[role="heading"]').map(&:text).select { |q| q.include?('?') }

      paa_questions = paa_questions.compact.uniq.reject(&:empty?)

      Rails.logger.info "Found #{paa_questions.size} PAA questions" if paa_questions.any?
      paa_questions
    rescue => e
      Rails.logger.error "PAA scraping failed: #{e.message}"
      []
    end
  end

  def scrape_related_searches
    Rails.logger.info "Scraping Related Searches for: #{@keyword}"

    begin
      uri = URI("https://www.google.com/search?q=#{URI.encode_www_form_component(@keyword)}")
      request = Net::HTTP::Get.new(uri)
      request["User-Agent"] = USER_AGENT

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 10) do |http|
        http.request(request)
      end

      doc = Nokogiri::HTML(response.body)

      # Extract related searches (usually at bottom of page)
      related = []

      # Try common related search selectors
      related += doc.css('.k8XOCe').map(&:text)
      related += doc.css('.s75CSd').map(&:text)
      related += doc.css('[data-ved] a').map(&:text).select { |t| t.length > 10 && t.length < 100 }

      related = related.compact.uniq.reject(&:empty?).map(&:downcase)

      Rails.logger.info "Found #{related.size} related searches" if related.any?
      related
    rescue => e
      Rails.logger.error "Related searches scraping failed: #{e.message}"
      []
    end
  end

  def scrape_organic_results
    Rails.logger.info "Scraping organic results for: #{@keyword}"

    begin
      uri = URI("https://www.google.com/search?q=#{URI.encode_www_form_component(@keyword)}")
      request = Net::HTTP::Get.new(uri)
      request["User-Agent"] = USER_AGENT

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 10) do |http|
        http.request(request)
      end

      doc = Nokogiri::HTML(response.body)

      # Extract organic search results
      results = []

      # Try to find result divs (Google's structure changes frequently)
      doc.css('div.g, div[data-sokoban-container]').each do |result_div|
        title_element = result_div.at_css('h3')
        link_element = result_div.at_css('a')

        next unless title_element && link_element

        url = link_element['href']
        next unless url&.start_with?('http')

        results << {
          title: title_element.text.strip,
          url: url
        }

        break if results.size >= 10
      end

      Rails.logger.info "Found #{results.size} organic results"
      results
    rescue => e
      Rails.logger.error "Organic results scraping failed: #{e.message}"
      []
    end
  end

  def fetch_all
    {
      people_also_ask: scrape_people_also_ask,
      related_searches: scrape_related_searches
    }
  end
end
