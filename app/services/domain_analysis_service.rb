# app/services/domain_analysis_service.rb
# Scrapes a domain to extract content, meta tags, and sitemap for context
class DomainAnalysisService
  require "net/http"
  require "nokogiri"
  require "uri"

  def initialize(domain)
    @domain = domain
    @results = {
      title: nil,
      meta_description: nil,
      h1s: [],
      h2s: [],
      content_summary: nil,
      sitemap_url: nil,
      sitemap_keywords: [],
      scraped_at: Time.current
    }
  end

  def analyze
    Rails.logger.info "Analyzing domain: #{@domain}"

    # Scrape homepage
    scrape_homepage

    # Try to find sitemap
    detect_sitemap

    @results
  rescue => e
    Rails.logger.error "Domain analysis failed for #{@domain}: #{e.message}"
    @results[:error] = e.message
    @results
  end

  private

  def scrape_homepage
    uri = URI(@domain)
    uri.path = "/" if uri.path.empty?

    response = fetch_with_retry(uri)
    return unless response

    doc = Nokogiri::HTML(response.body)

    # Extract meta tags
    @results[:title] = doc.at_css("title")&.text&.strip
    @results[:meta_description] = doc.at_css('meta[name="description"]')&.[]("content")&.strip

    # Extract headings
    @results[:h1s] = doc.css("h1").map { |h| h.text.strip }.reject(&:empty?).uniq
    @results[:h2s] = doc.css("h2").map { |h| h.text.strip }.reject(&:empty?).uniq.first(10)

    # Create content summary
    @results[:content_summary] = build_content_summary

    Rails.logger.info "Scraped homepage: title=#{@results[:title]}, h1s=#{@results[:h1s].size}, h2s=#{@results[:h2s].size}"
  end

  def detect_sitemap
    # Try common sitemap locations (including gzipped versions)
    sitemap_paths = [
      "/sitemap.xml",
      "/sitemap.xml.gz",
      "/sitemap_index.xml",
      "/sitemap_index.xml.gz",
      "/sitemap-index.xml",
      "/sitemap-index.xml.gz",
      "/sitemaps/sitemap.xml",
      "/sitemaps/sitemap.xml.gz"
    ]

    sitemap_paths.each do |path|
      uri = URI(@domain)
      uri.path = path

      response = fetch_with_retry(uri)
      next unless response&.code == "200"

      # Found a sitemap!
      @results[:sitemap_url] = uri.to_s

      # Decompress if gzipped
      content = if path.end_with?(".gz")
                  decompress_gzip(response.body)
      else
                  response.body
      end

      parse_sitemap(content)
      break
    end

    Rails.logger.info "Sitemap detected: #{@results[:sitemap_url]}" if @results[:sitemap_url]
  end

  def decompress_gzip(gzipped_content)
    require "zlib"
    require "stringio"

    gz = Zlib::GzipReader.new(StringIO.new(gzipped_content))
    gz.read
  ensure
    gz&.close
  end

  def parse_sitemap(xml_content)
    doc = Nokogiri::XML(xml_content)

    # Extract all URLs from sitemap
    urls = doc.css("url loc").map(&:text)

    # Convert URLs to potential keywords
    # Extract path segments that look like content topics
    @results[:sitemap_keywords] = urls.map do |url|
      uri = URI(url)
      # Get last path segment, clean it up
      path = uri.path.split("/").reject(&:empty?).last
      next unless path

      # Convert to readable keyword
      path.gsub(/[-_]/, " ").strip
    end.compact.uniq.first(20)

    Rails.logger.info "Parsed sitemap: #{urls.size} URLs, #{@results[:sitemap_keywords].size} potential keywords"
  rescue => e
    Rails.logger.warn "Failed to parse sitemap: #{e.message}"
  end

  def build_content_summary
    parts = []
    parts << "Title: #{@results[:title]}" if @results[:title]
    parts << "Description: #{@results[:meta_description]}" if @results[:meta_description]
    parts << "Main headings: #{@results[:h1s].join(', ')}" if @results[:h1s].any?
    parts << "Topics covered: #{@results[:h2s].first(5).join(', ')}" if @results[:h2s].any?

    parts.join("\n")
  end

  def fetch_with_retry(uri, max_retries: 2)
    retries = 0

    begin
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = (uri.scheme == "https")
      http.open_timeout = 10
      http.read_timeout = 10

      request = Net::HTTP::Get.new(uri.request_uri)
      request["User-Agent"] = "VerySimpleSEO Bot (SEO Content Analysis)"

      response = http.request(request)

      if response.code == "200"
        response
      else
        Rails.logger.warn "HTTP #{response.code} for #{uri}"
        nil
      end
    rescue Net::OpenTimeout, Net::ReadTimeout => e
      retries += 1
      if retries <= max_retries
        Rails.logger.warn "Timeout fetching #{uri}, retry #{retries}/#{max_retries}"
        sleep(2 ** retries) # Exponential backoff
        retry
      else
        Rails.logger.error "Failed to fetch #{uri} after #{max_retries} retries: #{e.message}"
        nil
      end
    rescue => e
      Rails.logger.error "Error fetching #{uri}: #{e.message}"
      nil
    end
  end
end
