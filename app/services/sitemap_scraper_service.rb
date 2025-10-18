# app/services/sitemap_scraper_service.rb
# Scrapes sitemap.xml (or fallback strategies) to discover all pages on a site
# Extracts metadata (title, description, headings) for internal link suggestions
class SitemapScraperService
  require 'net/http'
  require 'zlib'
  require 'nokogiri'

  def initialize(project)
    @project = project
    @discovered_pages = []
    @errors = []
  end

  def perform
    Rails.logger.info "Scraping content for: #{@project.domain}"

    # Try multiple discovery strategies
    pages = try_sitemap_xml ||
            try_sitemap_index ||
            try_robots_txt ||
            try_common_paths ||
            []

    if pages.empty?
      Rails.logger.warn "No pages discovered for #{@project.domain}"
      return { success: false, pages: [], errors: @errors }
    end

    # Scrape metadata from discovered pages (limit to 50 most important)
    scraped_pages = scrape_page_metadata(pages.take(50))

    # Store in project
    @project.update!(
      internal_content_index: {
        'pages' => scraped_pages,
        'last_scraped' => Time.current.iso8601,
        'discovery_method' => @discovery_method,
        'total_pages' => scraped_pages.size
      }
    )

    Rails.logger.info "Scraped #{scraped_pages.size} pages for #{@project.domain}"

    { success: true, pages: scraped_pages, errors: @errors }
  rescue => e
    Rails.logger.error "Sitemap scraping failed: #{e.message}"
    @errors << "Fatal error: #{e.message}"
    { success: false, pages: [], errors: @errors }
  end

  private

  # Strategy 1: Try sitemap.xml (most common)
  def try_sitemap_xml
    Rails.logger.info "Trying sitemap.xml discovery..."

    sitemap_url = @project.sitemap_url || "#{@project.domain}/sitemap.xml"

    begin
      response = fetch_url(sitemap_url)
      return nil unless response

      # Handle gzipped sitemaps
      xml_content = if sitemap_url.end_with?('.gz')
        Zlib::GzipReader.new(StringIO.new(response.body)).read
      else
        response.body
      end

      doc = Nokogiri::XML(xml_content)
      urls = doc.xpath('//xmlns:url/xmlns:loc').map(&:text)

      if urls.any?
        @discovery_method = 'sitemap.xml'
        Rails.logger.info "Found #{urls.size} URLs via sitemap.xml"
        return urls
      end
    rescue => e
      Rails.logger.info "sitemap.xml failed: #{e.message}"
      @errors << "sitemap.xml: #{e.message}"
    end

    nil
  end

  # Strategy 2: Try sitemap index (sitemaps of sitemaps)
  def try_sitemap_index
    Rails.logger.info "Trying sitemap index discovery..."

    sitemap_index_url = @project.sitemap_url&.gsub('sitemap.xml', 'sitemap_index.xml') ||
                        "#{@project.domain}/sitemap_index.xml"

    begin
      response = fetch_url(sitemap_index_url)
      return nil unless response

      doc = Nokogiri::XML(response.body)
      sitemap_urls = doc.xpath('//xmlns:sitemap/xmlns:loc').map(&:text)

      if sitemap_urls.any?
        all_urls = []
        sitemap_urls.first(5).each do |sitemap_url|  # Limit to first 5 sitemaps
          sitemap_response = fetch_url(sitemap_url)
          next unless sitemap_response

          sitemap_doc = Nokogiri::XML(sitemap_response.body)
          urls = sitemap_doc.xpath('//xmlns:url/xmlns:loc').map(&:text)
          all_urls.concat(urls)
        end

        if all_urls.any?
          @discovery_method = 'sitemap_index'
          Rails.logger.info "Found #{all_urls.size} URLs via sitemap index"
          return all_urls
        end
      end
    rescue => e
      Rails.logger.info "sitemap_index.xml failed: #{e.message}"
      @errors << "sitemap_index: #{e.message}"
    end

    nil
  end

  # Strategy 3: Try robots.txt (find sitemap location)
  def try_robots_txt
    Rails.logger.info "Trying robots.txt discovery..."

    robots_url = "#{@project.domain}/robots.txt"

    begin
      response = fetch_url(robots_url)
      return nil unless response

      # Parse robots.txt for Sitemap: directives
      sitemap_urls = response.body.scan(/Sitemap:\s*(.+)/i).flatten.map(&:strip)

      if sitemap_urls.any?
        # Try first sitemap found
        sitemap_response = fetch_url(sitemap_urls.first)
        return nil unless sitemap_response

        doc = Nokogiri::XML(sitemap_response.body)
        urls = doc.xpath('//xmlns:url/xmlns:loc').map(&:text)

        if urls.any?
          @discovery_method = 'robots.txt'
          Rails.logger.info "Found #{urls.size} URLs via robots.txt sitemap"
          return urls
        end
      end
    rescue => e
      Rails.logger.info "robots.txt failed: #{e.message}"
      @errors << "robots.txt: #{e.message}"
    end

    nil
  end

  # Strategy 4: Try common paths (fallback when no sitemap exists)
  def try_common_paths
    Rails.logger.info "Trying common path discovery (no sitemap found)..."

    common_paths = [
      '/blog',
      '/articles',
      '/pricing',
      '/features',
      '/about',
      '/contact',
      '/guides',
      '/resources',
      '/docs',
      '/help',
      '/support',
      '/faq',
      '/use-cases',
      '/solutions',
      '/product'
    ]

    discovered_urls = []

    # Check if common paths exist (return 200)
    common_paths.each do |path|
      url = "#{@project.domain}#{path}"
      begin
        response = fetch_url(url, follow_redirects: false)
        if response && response.code == '200'
          discovered_urls << url
          Rails.logger.info "Found: #{url}"
        end
      rescue
        # Path doesn't exist, continue
      end
    end

    # Also try to discover blog posts from /blog
    if discovered_urls.include?("#{@project.domain}/blog")
      blog_posts = discover_blog_posts("#{@project.domain}/blog")
      discovered_urls.concat(blog_posts) if blog_posts.any?
    end

    if discovered_urls.any?
      @discovery_method = 'common_paths'
      Rails.logger.info "Found #{discovered_urls.size} URLs via common paths"
      return discovered_urls
    end

    Rails.logger.warn "No pages discovered - all strategies failed"
    @errors << "All discovery strategies failed (no sitemap, no common paths)"
    []
  end

  # Try to discover blog posts from blog index page
  def discover_blog_posts(blog_url)
    response = fetch_url(blog_url)
    return [] unless response

    doc = Nokogiri::HTML(response.body)

    # Find all links that look like blog posts
    links = doc.css('a[href]').map { |link| link['href'] }
                              .select { |href| href.include?('/blog/') }
                              .map { |href| normalize_url(href) }
                              .uniq
                              .take(20)  # Limit to 20 blog posts

    Rails.logger.info "Discovered #{links.size} blog posts from #{blog_url}"
    links
  rescue => e
    Rails.logger.info "Blog discovery failed: #{e.message}"
    []
  end

  # Scrape metadata from each page
  def scrape_page_metadata(urls)
    urls.map do |url|
      begin
        response = fetch_url(url)
        next unless response

        doc = Nokogiri::HTML(response.body)

        {
          'url' => url,
          'title' => extract_title(doc),
          'meta_description' => extract_meta_description(doc),
          'headings' => extract_headings(doc),
          'summary' => extract_summary(doc),
          'scraped_at' => Time.current.iso8601
        }
      rescue => e
        Rails.logger.warn "Failed to scrape #{url}: #{e.message}"
        nil
      end
    end.compact
  end

  def extract_title(doc)
    doc.at_css('title')&.text&.strip ||
    doc.at_css('h1')&.text&.strip ||
    'Untitled'
  end

  def extract_meta_description(doc)
    doc.at_css('meta[name="description"]')&.[]('content')&.strip ||
    doc.at_css('meta[property="og:description"]')&.[]('content')&.strip ||
    ''
  end

  def extract_headings(doc)
    h2s = doc.css('h2').map { |h| h.text.strip }.reject(&:empty?)
    h3s = doc.css('h3').map { |h| h.text.strip }.reject(&:empty?)
    (h2s + h3s).take(10)  # Top 10 headings
  end

  def extract_summary(doc)
    # Get first paragraph
    first_p = doc.css('p').find { |p| p.text.strip.length > 50 }
    first_p&.text&.strip&.[](0..300) || ''
  end

  def fetch_url(url, follow_redirects: true, max_redirects: 5)
    uri = URI.parse(url)

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == 'https')
    http.open_timeout = 10
    http.read_timeout = 10

    request = Net::HTTP::Get.new(uri.request_uri)
    request['User-Agent'] = 'VerySimpleSEO Content Discovery Bot/1.0'

    response = http.request(request)

    # Handle redirects
    if follow_redirects && response.is_a?(Net::HTTPRedirection) && max_redirects > 0
      redirect_url = response['location']
      redirect_url = URI.join(url, redirect_url).to_s unless redirect_url.start_with?('http')
      return fetch_url(redirect_url, follow_redirects: true, max_redirects: max_redirects - 1)
    end

    return nil unless response.is_a?(Net::HTTPSuccess)

    response
  rescue => e
    Rails.logger.debug "Fetch failed for #{url}: #{e.message}"
    nil
  end

  def normalize_url(href)
    return href if href.start_with?('http')

    # Handle relative URLs
    if href.start_with?('/')
      "#{@project.domain}#{href}"
    else
      "#{@project.domain}/#{href}"
    end
  end
end
