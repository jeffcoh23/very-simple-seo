# Test all available models for article generation quality comparison
# Models to test: gpt-5, gpt-5-mini, claude-3-5-haiku, gemini-2.5-pro

require 'fileutils'

# Models to test with their configurations
MODELS_TO_TEST = [
  { name: "gpt-5", provider: "openai", model: "gpt-5" },
  { name: "gpt-5-mini", provider: "openai", model: "gpt-5-mini" },
  { name: "claude-3-5-haiku", provider: "anthropic", model: "claude-3-5-haiku-20241022" },
  { name: "gemini-2.5-pro", provider: "gemini", model: "gemini-2.5-pro" }
]

# Use Article 17 for testing
article = Article.find(17)
keyword = article.keyword
project = article.project

puts '=' * 100
puts 'MODEL COMPARISON TEST - Article Generation Quality'
puts '=' * 100
puts
puts "Article: #{article.title}"
puts "Keyword: #{keyword.keyword}"
puts "Project: #{project.name}"
puts
puts "Testing #{MODELS_TO_TEST.length} models:"
MODELS_TO_TEST.each { |m| puts "  • #{m[:name]}" }
puts
puts '=' * 100
puts

results = []

MODELS_TO_TEST.each_with_index do |model_config, index|
  puts
  puts "📝 TEST #{index + 1}/#{MODELS_TO_TEST.length}: #{model_config[:name]}"
  puts '-' * 100

  begin
    # Temporarily update the model configuration
    original_models = Ai::ClientService::MODELS.dup

    # Update all article generation services to use this model
    Ai::ClientService.const_set(:MODELS, {
      outline_generation: { provider: model_config[:provider], model: model_config[:model] },
      article_writing: { provider: model_config[:provider], model: model_config[:model] },
      article_improvement: { provider: model_config[:provider], model: model_config[:model] },
      keyword_analysis: { provider: "openai", model: "gpt-4o-mini" },
      serp_analysis: { provider: "openai", model: "gpt-4o-mini" },
      grounding_research: { provider: "gemini", model: "gemini-2.5-flash" },
      perplexity_search: { provider: "perplexity", model: "sonar" },
      openai_search: { provider: "openai", model: "gpt-4o" }
    }.freeze)

    puts "Model: #{model_config[:provider]}/#{model_config[:model]}"
    puts "Starting generation at: #{Time.current.strftime('%H:%M:%S')}"
    puts

    # Reset article
    article.update!(status: :pending, content: nil, serp_data: nil, outline: nil)

    # Time the generation
    start_time = Time.current
    service = ArticleGenerationService.new(article)
    result = service.perform
    end_time = Time.current
    duration = (end_time - start_time).round(1)

    article.reload

    if result && article.status == 'completed'
      puts "✅ SUCCESS"
      puts "Duration: #{duration}s"
      puts "Status: #{article.status}"
      puts "Word count: #{article.word_count}"

      # Save the article content for comparison
      output_file = Rails.root.join("tmp", "article_17_#{model_config[:name].gsub('-', '_')}.html")
      File.write(output_file, article.content)
      puts "Saved to: #{output_file}"

      results << {
        model: model_config[:name],
        success: true,
        duration: duration,
        word_count: article.word_count,
        status: article.status,
        file: output_file
      }
    else
      puts "❌ FAILED"
      puts "Status: #{article.status}"
      puts "Errors: #{article.errors.full_messages.join(', ')}" if article.errors.any?

      results << {
        model: model_config[:name],
        success: false,
        duration: duration,
        error: article.errors.full_messages.join(', ')
      }
    end

  rescue => e
    puts "❌ ERROR: #{e.message}"
    puts e.backtrace.first(3)

    results << {
      model: model_config[:name],
      success: false,
      error: e.message
    }
  ensure
    # Restore original configuration
    Ai::ClientService.const_set(:MODELS, original_models) if defined?(original_models)
  end

  puts '-' * 100

  # Add a small delay between tests to avoid rate limits
  sleep 2 unless index == MODELS_TO_TEST.length - 1
end

# Print summary
puts
puts
puts '=' * 100
puts 'SUMMARY OF RESULTS'
puts '=' * 100
puts

results.each do |result|
  if result[:success]
    puts "✅ #{result[:model].ljust(20)} - #{result[:duration]}s - #{result[:word_count]} words"
  else
    puts "❌ #{result[:model].ljust(20)} - FAILED: #{result[:error]}"
  end
end

puts
puts '=' * 100
puts 'NEXT STEPS'
puts '=' * 100
puts
puts "1. Review generated articles in tmp/ directory:"
results.select { |r| r[:success] }.each do |result|
  puts "   #{result[:file]}"
end
puts
puts "2. Run quality analysis on each:"
puts "   bin/rails runner scripts/analyze_article_17_detailed.rb"
puts
puts "3. Compare quality scores and select the best model"
puts
