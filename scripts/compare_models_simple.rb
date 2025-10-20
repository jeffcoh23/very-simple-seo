# Simple model comparison - regenerate article with each model and save results
# This avoids the complexity of dynamically changing MODELS constant

puts '=' * 100
puts 'MODEL COMPARISON TEST'
puts '=' * 100
puts
puts 'This script will test article generation with different models.'
puts 'Each test creates a separate article record to avoid conflicts.'
puts
puts 'Models to test:'
puts '  1. gpt-5-mini (current production model)'
puts '  2. gpt-5 (larger OpenAI model)'
puts '  3. claude-haiku-4-5 (Anthropic Haiku 4.5 - NEW)'
puts '  4. gemini-2.5-pro (Google)'
puts
puts '=' * 100

# Get the original article to copy
original_article = Article.find(17)
keyword = original_article.keyword
project = original_article.project

puts
puts "Source Article: #{original_article.title}"
puts "Keyword: #{keyword.keyword}"
puts "Project: #{project.name}"
puts

# Test configurations
test_configs = [
  {
    name: "GPT-5-mini",
    models: {
      outline_generation: { provider: "openai", model: "gpt-5-mini" },
      article_writing: { provider: "openai", model: "gpt-5-mini" },
      article_improvement: { provider: "openai", model: "gpt-5-mini" }
    }
  },
  {
    name: "GPT-5",
    models: {
      outline_generation: { provider: "openai", model: "gpt-5" },
      article_writing: { provider: "openai", model: "gpt-5" },
      article_improvement: { provider: "openai", model: "gpt-5" }
    }
  },
  {
    name: "Claude-Haiku-4.5",
    models: {
      outline_generation: { provider: "anthropic", model: "claude-haiku-4-5" },
      article_writing: { provider: "anthropic", model: "claude-haiku-4-5" },
      article_improvement: { provider: "anthropic", model: "claude-haiku-4-5" }
    }
  },
  {
    name: "Claude-Sonnet-4.5",
    models: {
      outline_generation: { provider: "anthropic", model: "claude-sonnet-4-5" },
      article_writing: { provider: "anthropic", model: "claude-sonnet-4-5" },
      article_improvement: { provider: "anthropic", model: "claude-sonnet-4-5" }
    }
  },
  {
    name: "Gemini-2.5-Pro",
    models: {
      outline_generation: { provider: "gemini", model: "gemini-2.5-pro" },
      article_writing: { provider: "gemini", model: "gemini-2.5-pro" },
      article_improvement: { provider: "gemini", model: "gemini-2.5-pro" }
    }
  }
]

puts
puts "Strategy: Will manually update Ai::ClientService::MODELS and regenerate Article 17"
puts "Article 17 content will be saved to tmp/ after each test"
puts
puts 'Press Enter to continue...'
# gets # Uncomment if you want manual confirmation

results_dir = Rails.root.join("tmp", "model_comparison_#{Time.current.to_i}")
FileUtils.mkdir_p(results_dir)

results = []

test_configs.each_with_index do |config, index|
  puts
  puts '=' * 100
  puts "TEST #{index + 1}/#{test_configs.length}: #{config[:name]}"
  puts '=' * 100
  puts

  begin
    puts "Models:"
    puts "  Outline: #{config[:models][:outline_generation][:provider]}/#{config[:models][:outline_generation][:model]}"
    puts "  Writing: #{config[:models][:article_writing][:provider]}/#{config[:models][:article_writing][:model]}"
    puts "  Improvement: #{config[:models][:article_improvement][:provider]}/#{config[:models][:article_improvement][:model]}"
    puts

    # Build the new MODELS hash
    new_models = {
      outline_generation: config[:models][:outline_generation],
      article_writing: config[:models][:article_writing],
      article_improvement: config[:models][:article_improvement],
      keyword_analysis: { provider: "openai", model: "gpt-4o-mini" },
      serp_analysis: { provider: "openai", model: "gpt-4o-mini" },
      grounding_research: { provider: "gemini", model: "gemini-2.5-flash" },
      perplexity_search: { provider: "perplexity", model: "sonar" },
      openai_search: { provider: "openai", model: "gpt-4o" }
    }.freeze

    # Temporarily replace the MODELS constant
    Ai::ClientService.send(:remove_const, :MODELS)
    Ai::ClientService.const_set(:MODELS, new_models)

    puts "✓ Updated model configuration"
    puts

    # Reset Article 17
    original_article.update!(status: :pending, content: nil, serp_data: nil, outline: nil)
    puts "✓ Reset article status"
    puts

    # Generate
    puts "Generating article..."
    start_time = Time.current
    service = ArticleGenerationService.new(original_article)
    result = service.perform
    duration = (Time.current - start_time).round(1)

    original_article.reload

    if result && original_article.status == 'completed'
      puts
      puts "✅ SUCCESS"
      puts "   Duration: #{duration}s"
      puts "   Word count: #{original_article.word_count}"
      puts "   Status: #{original_article.status}"

      # Save content
      filename = "article_17_#{config[:name].downcase.gsub(/[^a-z0-9]/, '_')}.html"
      filepath = results_dir.join(filename)
      File.write(filepath, original_article.content)
      puts "   Saved: #{filepath}"

      results << {
        model: config[:name],
        success: true,
        duration: duration,
        word_count: original_article.word_count,
        file: filepath
      }
    else
      puts
      puts "❌ FAILED"
      puts "   Status: #{original_article.status}"

      results << {
        model: config[:name],
        success: false,
        duration: duration,
        error: "Generation failed"
      }
    end

  rescue => e
    puts
    puts "❌ ERROR: #{e.class} - #{e.message}"
    puts e.backtrace.first(3).map { |line| "   #{line}" }.join("\n")

    results << {
      model: config[:name],
      success: false,
      error: "#{e.class}: #{e.message}"
    }
  end

  puts
  puts "Waiting 3 seconds before next test..."
  sleep 3
end

# Print summary
puts
puts
puts '=' * 100
puts 'FINAL RESULTS'
puts '=' * 100
puts

successful = results.select { |r| r[:success] }
failed = results.reject { |r| r[:success] }

if successful.any?
  puts "✅ Successful Generations (#{successful.length}):"
  puts
  successful.sort_by { |r| r[:duration] }.each do |result|
    puts "  #{result[:model].ljust(25)} #{result[:duration].to_s.rjust(6)}s   #{result[:word_count].to_s.rjust(5)} words"
  end
  puts
end

if failed.any?
  puts "❌ Failed Generations (#{failed.length}):"
  puts
  failed.each do |result|
    puts "  #{result[:model].ljust(25)} ERROR: #{result[:error]}"
  end
  puts
end

puts '=' * 100
puts 'SAVED FILES'
puts '=' * 100
puts
puts "All generated articles saved to:"
puts "  #{results_dir}"
puts
successful.each do |result|
  puts "  #{File.basename(result[:file])}"
end
puts
puts '=' * 100
puts 'NEXT STEPS'
puts '=' * 100
puts
puts "1. Review the generated HTML files in #{results_dir}"
puts "2. Compare quality, tone, and SEO optimization"
puts "3. Select the best performing model"
puts "4. Update Ai::ClientService::MODELS to use the winner"
puts
