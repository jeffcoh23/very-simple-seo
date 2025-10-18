# app/services/article_generation_service.rb
# Orchestrates the complete article generation pipeline
class ArticleGenerationService
  def initialize(article)
    @article = article
    @keyword = article.keyword
    @project = article.project
  end

  def perform
    total_cost = 0.0

    begin
      @article.update!(status: :generating, started_at: Time.current)
      Rails.logger.info "=" * 80
      Rails.logger.info "ARTICLE GENERATION: #{@keyword.keyword}"
      Rails.logger.info "=" * 80

      # Step 1: SERP Research
      # SWITCH BETWEEN OLD AND NEW APPROACH HERE:

      # NEW: Google Grounding (recommended) - uncomment to use
      serp_result = perform_grounding_research

      # OLD: HTML Scraping (fallback) - uncomment to use
      # serp_result = perform_serp_research

      total_cost += serp_result[:cost]

      if serp_result[:data].nil?
        fail_article("SERP research failed", total_cost)
        return
      end

      @article.update!(serp_data: serp_result[:data])

      # Step 2: Generate Outline
      outline_result = generate_outline(serp_result[:data])
      total_cost += outline_result[:cost]

      if outline_result[:data].nil?
        fail_article("Outline generation failed", total_cost)
        return
      end

      @article.update!(outline: outline_result[:data])

      # Step 3: Write Article
      writing_result = write_article(outline_result[:data], serp_result[:data])
      total_cost += writing_result[:cost]

      if writing_result[:data].nil?
        fail_article("Article writing failed", total_cost)
        return
      end

      @article.update!(content: writing_result[:data])

      # Step 4: Improve Article
      improvement_result = improve_article(writing_result[:data], serp_result[:data])
      total_cost += improvement_result[:cost]

      if improvement_result[:data].nil?
        fail_article("Article improvement failed", total_cost)
        return
      end

      @article.update!(content: improvement_result[:data])

      # Calculate final stats
      word_count = improvement_result[:data].split.size

      # Extract title and meta from outline
      title = outline_result[:data]['title']
      meta_description = outline_result[:data]['meta_description']

      @article.update!(
        title: title,
        meta_description: meta_description,
        word_count: word_count,
        generation_cost: total_cost,
        status: :completed,
        completed_at: Time.current
      )

      Rails.logger.info "=" * 80
      Rails.logger.info "ARTICLE COMPLETE"
      Rails.logger.info "Word count: #{word_count}"
      Rails.logger.info "AI cost: $#{total_cost.round(2)}"
      Rails.logger.info "Duration: #{(Time.current - @article.started_at).round(1)}s"
      Rails.logger.info "=" * 80

    rescue => e
      Rails.logger.error "Article generation failed: #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")
      fail_article("Unexpected error: #{e.message}", total_cost)
    end
  end

  private

  # NEW: Google Grounding research
  def perform_grounding_research
    Rails.logger.info "\n[1/4] Grounding Research (NEW)"
    Rails.logger.info "-" * 40

    service = SerpGroundingResearchService.new(@keyword.keyword, project: @project)
    service.perform
  end

  # OLD: HTML scraping research
  def perform_serp_research
    Rails.logger.info "\n[1/4] SERP Research (OLD - HTML Scraping)"
    Rails.logger.info "-" * 40

    service = SerpResearchService.new(@keyword.keyword)
    service.perform
  end

  def generate_outline(serp_data)
    Rails.logger.info "\n[2/4] Generating Outline"
    Rails.logger.info "-" * 40

    voice_profile = @article.project.respond_to?(:voice_profile) ? @article.project.voice_profile : nil
    service = ArticleOutlineService.new(@keyword.keyword, serp_data, voice_profile: voice_profile, project: @project)
    service.perform
  end

  def write_article(outline, serp_data)
    Rails.logger.info "\n[3/4] Writing Article"
    Rails.logger.info "-" * 40

    voice_profile = @article.project.respond_to?(:voice_profile) ? @article.project.voice_profile : nil
    service = ArticleWriterService.new(@keyword.keyword, outline, serp_data, voice_profile: voice_profile, project: @project)
    service.perform
  end

  def improve_article(markdown, serp_data)
    Rails.logger.info "\n[4/4] Improving Article"
    Rails.logger.info "-" * 40

    service = ArticleImprovementService.new(markdown, serp_data, project: @project)
    service.perform
  end

  def fail_article(error_message, total_cost)
    @article.update!(
      status: :failed,
      error_message: error_message,
      generation_cost: total_cost,
      completed_at: Time.current
    )
    Rails.logger.error "FAILED: #{error_message}"
  end
end
