# app/services/internal_link_suggester.rb
# Analyzes project's existing articles and CTAs to suggest contextual internal links
# Used by Grounding research to build internal linking context

class InternalLinkSuggester
  def initialize(project)
    @project = project
  end

  # Build context about project's pages for Grounding to use
  # Returns hash with existing articles, CTAs, and linking guidelines
  def build_internal_linking_context
    {
      "existing_articles" => gather_existing_articles,
      "ctas" => gather_ctas,
      "linking_guidelines" => build_linking_guidelines
    }
  end

  private

  def gather_existing_articles
    # NEW: Use scraped sitemap data if available (REAL URLs from live site)
    if @project.internal_content_index.present? && @project.internal_content_index["pages"].present?
      scraped_pages = @project.internal_content_index["pages"] || []

      if scraped_pages.any?
        Rails.logger.info "Using #{scraped_pages.size} scraped pages for internal links"
        return scraped_pages.map do |page|
          {
            "title" => page["title"],
            "keyword" => extract_keyword_from_url(page["url"]),
            "url" => page["url"],  # REAL URL like /blog/validate-ideas
            "meta_description" => page["meta_description"],
            "word_count" => estimate_word_count(page["summary"]),
            "topics" => page["headings"] || []
          }
        end
      end
    end

    # FALLBACK: Use database articles (generates /articles/:id URLs)
    # NOTE: These URLs may not exist on the actual site!
    Rails.logger.warn "No scraped content found - falling back to database articles"
    Rails.logger.warn "WARNING: Generated URLs may be broken. Run SitemapScraperService to fix."

    articles = @project.articles.where(status: :completed).order(created_at: :desc).limit(50)

    articles.map do |article|
      {
        "title" => article.title,
        "keyword" => article.keyword&.keyword,
        "url" => article_url(article),
        "meta_description" => article.meta_description,
        "word_count" => article.word_count,
        "topics" => extract_topics_from_article(article)
      }
    end
  end

  def gather_ctas
    # Get CTAs from project
    return [] unless @project.call_to_actions.present?

    @project.call_to_actions.map do |cta|
      {
        "text" => cta["text"],
        "url" => cta["url"],
        "context" => infer_cta_context(cta)
      }
    end
  end

  def build_linking_guidelines
    <<~GUIDELINES
      Internal Linking Rules:
      1. Link to existing articles when naturally relevant
      2. Use descriptive anchor text (not "click here")
      3. Place 3-5 internal links per article
      4. Link early in article (first 500 words)
      5. Use project CTAs 1-2 times maximum
      6. Prioritize recent/relevant articles over old ones
      7. Don't force links - only when contextually appropriate
    GUIDELINES
  end

  def extract_topics_from_article(article)
    # Extract key topics from article content
    # Simple approach: extract H2 headings from outline
    return [] unless article.outline.present?

    sections = article.outline["sections"] || []
    sections.map { |s| s["heading"] }.compact
  end

  def infer_cta_context(cta)
    # Infer what the CTA is for based on text/URL
    text = cta["text"].to_s.downcase
    url = cta["url"].to_s.downcase

    if text.include?("sign up") || text.include?("signup") || url.include?("signup")
      "user_registration"
    elsif text.include?("demo") || url.include?("demo")
      "product_demo"
    elsif text.include?("pricing") || url.include?("pricing")
      "pricing_page"
    elsif text.include?("download") || text.include?("get") && text.include?("free")
      "free_resource"
    elsif text.include?("contact") || url.include?("contact")
      "contact_sales"
    elsif text.include?("trial") || text.include?("free") || url.include?("trial")
      "free_trial"
    else
      "general_cta"
    end
  end

  def article_url(article)
    # Generate URL for article
    # This assumes articles are at /articles/:id or similar
    # Adjust based on your routing
    "/articles/#{article.id}"
  end

  # NEW: Helper methods for scraped content
  def extract_keyword_from_url(url)
    # Extract keyword from URL slug
    # e.g., "/blog/validate-business-ideas" → "validate business ideas"
    slug = url.split("/").last
    slug&.gsub("-", " ")&.gsub("_", " ") || ""
  end

  def estimate_word_count(summary)
    # Rough estimate from summary
    return 0 if summary.blank?
    (summary.split.size * 8) # Assume summary is ~12% of content
  end
end
