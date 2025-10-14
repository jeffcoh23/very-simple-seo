# app/jobs/article_generation_job.rb
class ArticleGenerationJob < ApplicationJob
  queue_as :default

  def perform(article_id)
    @article = Article.find(article_id)
    @total_cost = 0.0

    Rails.logger.info "Starting ArticleGenerationJob for Article ID: #{article_id}"

    # Start generating
    @article.update!(status: :generating, started_at: Time.current)
    broadcast_progress("Starting article generation...")

    # Step 1: SERP Research
    broadcast_progress("🔍 Researching top 10 Google results...")
    serp_result = perform_serp_research
    @total_cost += serp_result[:cost]

    if serp_result[:data].nil?
      fail_with_message("SERP research failed", @total_cost)
      return
    end

    @article.update!(serp_data: serp_result[:data])
    broadcast_progress("✅ Found #{serp_result[:data]['common_topics']&.size || 0} common topics from competitors")

    # Step 2: Generate Outline
    broadcast_progress("📝 Generating article outline with AI...")
    outline_result = generate_outline(serp_result[:data])
    @total_cost += outline_result[:cost]

    if outline_result[:data].nil?
      fail_with_message("Outline generation failed", @total_cost)
      return
    end

    @article.update!(outline: outline_result[:data])
    target_words = outline_result[:data]['sections']&.sum { |s| s['target_word_count'] || 0 } || 2000
    broadcast_progress("✅ Outline created (targeting #{target_words} words)")

    # Step 3: Write Article
    broadcast_progress("✍️ Writing article sections with GPT-4o Mini...")
    writing_result = write_article(outline_result[:data], serp_result[:data])
    @total_cost += writing_result[:cost]

    if writing_result[:data].nil?
      fail_with_message("Article writing failed", @total_cost)
      return
    end

    @article.update!(content: writing_result[:data])
    word_count = writing_result[:data].split.size
    broadcast_progress("✅ Draft complete (#{word_count} words)")

    # Step 4: Improve Article
    broadcast_progress("✨ Improving article quality (3 passes)...")
    improvement_result = improve_article(writing_result[:data], serp_result[:data])
    @total_cost += improvement_result[:cost]

    if improvement_result[:data].nil?
      fail_with_message("Article improvement failed", @total_cost)
      return
    end

    @article.update!(content: improvement_result[:data])

    # Calculate final stats
    final_word_count = improvement_result[:data].split.size

    # Extract title and meta from outline
    title = outline_result[:data]['title']
    meta_description = outline_result[:data]['meta_description']

    @article.update!(
      title: title,
      meta_description: meta_description,
      word_count: final_word_count,
      generation_cost: @total_cost,
      status: :completed,
      completed_at: Time.current
    )

    duration = (Time.current - @article.started_at).round(1)
    broadcast_progress("🎉 Article complete! #{final_word_count} words • $#{@total_cost.round(2)} • #{duration}s")

    Rails.logger.info "ArticleGenerationJob completed for Article ID: #{article_id}"

  rescue ActiveRecord::RecordNotFound
    Rails.logger.error "Article ID #{article_id} not found"
  rescue => e
    Rails.logger.error "ArticleGenerationJob failed: #{e.message}"
    Rails.logger.error e.backtrace.first(5).join("\n")

    # Mark article as failed if it exists
    if @article
      @article.update!(
        status: :failed,
        error_message: "Job error: #{e.message}",
        generation_cost: @total_cost,
        completed_at: Time.current
      )
      broadcast_progress("❌ Generation failed: #{e.message}")
    end
  end

  private

  def perform_serp_research
    service = SerpResearchService.new(@article.keyword.keyword)
    service.perform
  end

  def generate_outline(serp_data)
    # Voice profile is NOT used for outlines, only for writing
    service = ArticleOutlineService.new(
      @article.keyword.keyword,
      serp_data,
      voice_profile: nil,
      target_word_count: @article.target_word_count
    )
    service.perform
  end

  def write_article(outline, serp_data)
    # Voice profile is on User model, not Project
    voice_profile = @article.project.user.voice_profile
    service = ArticleWriterService.new(@article.keyword.keyword, outline, serp_data, voice_profile: voice_profile)
    service.perform
  end

  def improve_article(markdown, serp_data)
    service = ArticleImprovementService.new(markdown, serp_data)
    service.perform
  end

  def fail_with_message(error_message, cost)
    @article.update!(
      status: :failed,
      error_message: error_message,
      generation_cost: cost,
      completed_at: Time.current
    )
    broadcast_progress("❌ #{error_message}")
  end

  def broadcast_progress(message)
    ArticleChannel.broadcast_to(
      @article,
      {
        id: @article.id,
        status: @article.status,
        word_count: @article.word_count,
        generation_cost: @total_cost,
        progress_message: message,
        started_at: @article.started_at,
        completed_at: @article.completed_at,
        error_message: @article.error_message
      }
    )
  end
end
