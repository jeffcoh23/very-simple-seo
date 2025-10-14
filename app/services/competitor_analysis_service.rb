# app/services/competitor_analysis_service.rb
# Analyzes competitor websites for keyword opportunities
class CompetitorAnalysisService
  USER_AGENT = "Mozilla/5.0 (compatible; VerySimpleSEO/1.0)"

  def initialize(project)
    @project = project
  end

  def analyze_all
    keywords = []

    @project.competitors.each do |competitor|
      Rails.logger.info "Analyzing competitor: #{competitor.domain}"

      # Scrape sitemap for page URLs
      sitemap_keywords = scrape_sitemap(competitor.domain)
      keywords.concat(sitemap_keywords.map { |kw| { keyword: kw, source: competitor.domain } })

      # Scrape key pages for titles/H1s
      page_keywords = scrape_pages(competitor.domain)
      keywords.concat(page_keywords.map { |kw| { keyword: kw, source: competitor.domain } })

      sleep 1 # Be nice to competitors
    end

    keywords
  end

  def scrape_sitemap(domain)
    Rails.logger.info "Scraping sitemap for: #{domain}"

    sitemap_urls = [
      "https://#{domain}/sitemap.xml",
      "https://#{domain}/sitemap_index.xml",
      "https://www.#{domain}/sitemap.xml"
    ]

    keywords = []

    sitemap_urls.each do |sitemap_url|
      begin
        uri = URI(sitemap_url)
        request = Net::HTTP::Get.new(uri)
        request["User-Agent"] = USER_AGENT

        response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 10) do |http|
          http.request(request)
        end

        next unless response.code == '200'

        xml = Nokogiri::XML(response.body)

        # Extract URLs from sitemap
        urls = xml.xpath('//xmlns:loc').map(&:text)

        # Convert URLs to keywords
        urls.each do |url|
          # Extract path segment: "https://example.com/validate-startup-idea" → "validate startup idea"
          path = URI(url).path
          segments = path.split('/').reject(&:empty?)

          segments.each do |segment|
            keyword = segment.gsub(/[-_]/, ' ').downcase
            keywords << keyword if keyword.length > 5 && keyword.length < 100
          end
        end

        Rails.logger.info "Found #{urls.size} pages in sitemap"
        break # Found a working sitemap
      rescue => e
        # Try next sitemap URL
        next
      end
    end

    Rails.logger.warn "No sitemap found for #{domain}" if keywords.empty?
    keywords.uniq
  end

  def scrape_pages(domain)
    Rails.logger.info "Scraping key pages for: #{domain}"

    keywords = []
    urls_to_check = [
      "https://#{domain}",
      "https://#{domain}/features",
      "https://#{domain}/pricing",
      "https://#{domain}/blog"
    ]

    urls_to_check.each do |url|
      begin
        uri = URI(url)
        request = Net::HTTP::Get.new(uri)
        request["User-Agent"] = USER_AGENT

        response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 10) do |http|
          http.request(request)
        end

        next unless response.code == '200'

        doc = Nokogiri::HTML(response.body)

        # Extract title tag
        title = doc.at_css('title')&.text
        keywords << title.downcase if title && title.length < 100

        # Extract H1s
        h1s = doc.css('h1').map(&:text).map(&:downcase)
        keywords.concat(h1s.select { |h| h.length > 5 && h.length < 100 })

        # Extract H2s (might contain keyword phrases)
        h2s = doc.css('h2').map(&:text).map(&:downcase)
        keywords.concat(h2s.select { |h| h.length > 5 && h.length < 100 })

        # Extract meta description
        meta_desc = doc.at_css('meta[name="description"]')
        keywords << meta_desc['content'].downcase if meta_desc && meta_desc['content']

      rescue => e
        # Page failed, continue to next
        next
      end
    end

    Rails.logger.info "Found #{keywords.size} keywords from pages" if keywords.any?
    keywords.compact.uniq
  end
end
