article = Article.find(17)

puts '=' * 80
puts 'REGENERATING ARTICLE #17 WITH CLAUDE HAIKU 4.5'
puts '=' * 80
puts 'Model: claude-haiku-4.5 (as per RubyLLM docs)'
puts

# Reset article
article.update!(status: :pending, content: nil, serp_data: nil, outline: nil)

# Regenerate
service = ArticleGenerationService.new(article)
result = service.perform

if result
  article.reload
  puts "✓ Success! Word count: #{article.word_count}"
else
  puts '✗ Failed'
end
