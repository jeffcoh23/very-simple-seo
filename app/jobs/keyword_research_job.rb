# app/jobs/keyword_research_job.rb
# Background job for running keyword research
class KeywordResearchJob < ApplicationJob
  queue_as :default

  def perform(keyword_research_id)
    @keyword_research = KeywordResearch.find(keyword_research_id)

    Rails.logger.info "Starting KeywordResearchJob for ID: #{keyword_research_id}"

    # Update status to processing
    @keyword_research.update!(
      status: :processing,
      started_at: Time.current
    )
    broadcast_progress("Starting keyword research...")

    # Run the keyword research service with progress callbacks
    service = KeywordResearchService.new(@keyword_research)

    # Step 1: Generate seed keywords
    broadcast_progress("🌱 Generating seed keywords from your domain...")
    service.send(:generate_seed_keywords)
    seed_count = @keyword_research.seed_keywords.size
    @keyword_research.seed_keywords.first(10).each do |seed|
      broadcast_progress("→ #{seed}", indent: 1)
    end
    if seed_count > 10
      broadcast_progress("→ ... and #{seed_count - 10} more", indent: 1)
    end
    broadcast_progress("✅ Generated #{seed_count} seed keywords")

    # Step 2: Expand keywords
    broadcast_progress("🔍 Expanding keywords via Google autocomplete...")
    @keyword_research.seed_keywords.first(5).each do |seed|
      broadcast_progress("→ Expanding: #{seed}", indent: 1)
    end
    if @keyword_research.seed_keywords.size > 5
      broadcast_progress("→ ... expanding #{@keyword_research.seed_keywords.size - 5} more seeds", indent: 1)
    end
    service.send(:expand_keywords)
    total_found = service.instance_variable_get(:@keywords).size
    broadcast_progress("✅ Found #{total_found} total keywords after expansion")

    # Step 3: Mine Reddit
    broadcast_progress("📱 Mining Reddit for topic ideas...")
    service.send(:mine_reddit)
    broadcast_progress("✅ Mined Reddit discussions")

    # Step 4: Analyze competitors
    if @keyword_research.project.competitors.any?
      competitor_count = @keyword_research.project.competitors.count
      broadcast_progress("🔎 Analyzing #{competitor_count} competitor#{competitor_count > 1 ? 's' : ''}...")
      @keyword_research.project.competitors.each do |competitor|
        broadcast_progress("→ Scraping: #{competitor.domain}", indent: 1)
      end
      service.send(:analyze_competitors)
      broadcast_progress("✅ Scraped competitor content")
    end

    # Step 5: Calculate metrics
    total_keywords = service.instance_variable_get(:@keywords).size
    broadcast_progress("📊 Calculating metrics for #{total_keywords} keywords...")
    use_google_ads = ENV['GOOGLE_ADS_DEVELOPER_TOKEN'].present?
    if use_google_ads
      broadcast_progress("→ Using Google Ads API for accurate data", indent: 1)
    else
      broadcast_progress("→ Using heuristic estimates", indent: 1)
    end
    service.send(:calculate_metrics)
    broadcast_progress("✅ Metrics calculated (volume, difficulty, CPC, opportunity)")

    # Step 6: Save top keywords
    broadcast_progress("💾 Saving top 30 keywords...")
    service.send(:save_keywords)

    # Mark as completed
    @keyword_research.update!(
      status: :completed,
      total_keywords_found: total_keywords,
      completed_at: Time.current
    )
    broadcast_progress("🎉 Research complete! Found #{@keyword_research.keywords.count} opportunities")

    Rails.logger.info "KeywordResearchJob completed for ID: #{keyword_research_id}"

  rescue => e
    Rails.logger.error "KeywordResearchJob failed for ID: #{keyword_research_id}"
    Rails.logger.error "Error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    # Update status to failed
    @keyword_research.update!(
      status: :failed,
      error_message: e.message,
      completed_at: Time.current
    )
    broadcast_progress("❌ Research failed: #{e.message}")

    raise
  end

  private

  def broadcast_progress(message, indent: 0)
    # Add to progress log
    @keyword_research.add_progress_log(message, indent: indent)

    # Broadcast via ActionCable
    KeywordResearchChannel.broadcast_to(
      @keyword_research,
      {
        id: @keyword_research.id,
        status: @keyword_research.status,
        total_keywords_found: @keyword_research.total_keywords_found,
        progress_message: message,
        progress_log: @keyword_research.progress_log,
        started_at: @keyword_research.started_at,
        completed_at: @keyword_research.completed_at,
        error_message: @keyword_research.error_message
      }
    )
  end
end
