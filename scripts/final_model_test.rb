# Final test with 16000 token limit for GPT-5-mini and Gemini
# Compare with Claude results

require 'fileutils'

puts '=' * 100
puts 'FINAL MODEL TEST - With 16K Token Limit'
puts '=' * 100
puts
puts 'Testing with max_tokens: 16000'
puts '  - GPT-5-mini (retry with higher limit)'
puts '  - Gemini 2.5 Pro (retry with higher limit)'
puts
puts '=' * 100
puts

# Get the original article
original_article = Article.find(17)
keyword = original_article.keyword
project = original_article.project

puts "Article: #{original_article.title}"
puts "Keyword: #{keyword.keyword}"
puts "Project: #{project.name}"
puts

# Test configurations
test_configs = [
  {
    name: "GPT-5-mini-16k",
    models: {
      outline_generation: { provider: "openai", model: "gpt-5-mini" },
      article_writing: { provider: "openai", model: "gpt-5-mini" },
      article_improvement: { provider: "openai", model: "gpt-5-mini" }
    }
  },
  {
    name: "Gemini-2.5-Pro-16k",
    models: {
      outline_generation: { provider: "gemini", model: "gemini-2.5-pro" },
      article_writing: { provider: "gemini", model: "gemini-2.5-pro" },
      article_improvement: { provider: "gemini", model: "gemini-2.5-pro" }
    }
  }
]

results_dir = Rails.root.join("tmp", "model_final_16k_#{Time.current.to_i}")
FileUtils.mkdir_p(results_dir)

results = []

test_configs.each_with_index do |config, index|
  puts
  puts '=' * 100
  puts "TEST #{index + 1}/#{test_configs.length}: #{config[:name]}"
  puts '=' * 100
  puts

  begin
    puts "Configuration:"
    puts "  Model: #{config[:models][:article_writing][:provider]}/#{config[:models][:article_writing][:model]}"
    puts "  Token Limit: 16000 (very high)"
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
    puts "Generating article with 16K token limit..."
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
      puts "   Error: #{original_article.error_message}" if original_article.error_message.present?

      results << {
        model: config[:name],
        success: false,
        duration: duration,
        error: original_article.error_message || "Generation failed"
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

# Print final comparison
puts
puts
puts '=' * 100
puts 'FINAL COMPARISON - ALL MODELS'
puts '=' * 100
puts

puts "Model Performance Summary:"
puts
puts "Claude Models (from previous test):"
puts "  Claude Haiku 4.5          397s     2,694 words   ✅✅✅ BEST"
puts "  Claude Sonnet 4.5         453s     2,659 words   ✅✅✅"
puts

puts "OpenAI Models:"
puts "  GPT-5-mini (no limit)     505s       177 words   ❌ (skeleton only)"
puts "  GPT-5-mini (16K limit)   #{results[0][:success] ? "#{results[0][:duration].to_s.rjust(5)}s   #{results[0][:word_count].to_s.rjust(7)} words" : 'FAILED'}   #{results[0][:success] ? '✅' : '❌'}"
puts

puts "Google Models:"
puts "  Gemini 2.5 Pro (no limit)  440s       442 words   ⚠️  (incomplete)"
puts "  Gemini 2.5 Pro (16K limit) #{results[1][:success] ? "#{results[1][:duration].to_s.rjust(4)}s   #{results[1][:word_count].to_s.rjust(7)} words" : 'FAILED'}   #{results[1][:success] ? '✅' : '❌'}"
puts

puts '=' * 100
puts 'RECOMMENDATION'
puts '=' * 100
puts

if results.any? { |r| r[:success] && r[:word_count] > 2000 }
  best = results.select { |r| r[:success] && r[:word_count] > 2000 }.sort_by { |r| r[:duration] }.first
  puts "✅ New winner found: #{best[:model]}"
  puts "   #{best[:word_count]} words in #{best[:duration]}s"
  puts
  puts "   Compare with Claude Haiku 4.5: 2,694 words in 397s"
else
  puts "✅ WINNER: Claude Haiku 4.5"
  puts "   - Fastest: 397s"
  puts "   - Most complete: 2,694 words"
  puts "   - Most reliable: No errors"
  puts "   - Best quality: 8.5/10"
  puts
  puts "   Update production config:"
  puts "   outline_generation: { provider: 'anthropic', model: 'claude-haiku-4-5' }"
  puts "   article_writing: { provider: 'anthropic', model: 'claude-haiku-4-5' }"
  puts "   article_improvement: { provider: 'anthropic', model: 'claude-haiku-4-5' }"
end
puts
puts '=' * 100
