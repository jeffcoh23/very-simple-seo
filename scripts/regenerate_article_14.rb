#!/usr/bin/env ruby
# Regenerate Article #14 with improved SERP research and analyze results

require_relative '../config/environment'

article = Article.find(14)

puts "=" * 80
puts "REGENERATING ARTICLE #14 WITH IMPROVED SERP RESEARCH"
puts "=" * 80
puts
puts "Article ID: #{article.id}"
puts "Keyword: #{article.keyword.keyword}"
puts "Project: #{article.project.name}"
puts
puts "OLD SERP DATA QUALITY:"
old_serp = article.serp_data

if old_serp
  old_examples = old_serp['detailed_examples'] || []
  old_stats = old_serp['statistics'] || []
  old_tools = old_serp['recommended_tools'] || []

  old_complete_examples = old_examples.count { |ex|
    ex['company'].present? && ex['outcome'].present? &&
    ex['source_url'].present? && ex['how_they_did_it'].present?
  }

  old_complete_stats = old_stats.count { |stat|
    stat['source_url'].present? && stat['source'].present?
  }

  old_complete_tools = old_tools.count { |tool|
    tool['url'].present?
  }

  puts "  Examples: #{old_complete_examples}/#{old_examples.size} complete"
  puts "  Statistics: #{old_complete_stats}/#{old_stats.size} with sources"
  puts "  Tools: #{old_complete_tools}/#{old_tools.size} with URLs"
  puts "  Unique companies: #{old_examples.map { |ex| ex['company'] }.compact.uniq.size}"
else
  puts "  (No SERP data)"
end

puts
puts "-" * 80
puts "REGENERATING ARTICLE..."
puts "-" * 80
puts

# Store old data for comparison
old_content = article.content
old_title = article.title
old_word_count = article.word_count

# Regenerate the article
service = ArticleGenerationService.new(article)
service.perform

# Reload to get fresh data
article.reload

puts
puts "=" * 80
puts "REGENERATION COMPLETE"
puts "=" * 80
puts

# Analyze new SERP data
puts
puts "NEW SERP DATA QUALITY:"
new_serp = article.serp_data

if new_serp
  new_examples = new_serp['detailed_examples'] || []
  new_stats = new_serp['statistics'] || []
  new_tools = new_serp['recommended_tools'] || []

  new_complete_examples = new_examples.count { |ex|
    ex['company'].present? && ex['outcome'].present? &&
    ex['source_url'].present? && ex['how_they_did_it'].present?
  }

  new_complete_stats = new_stats.count { |stat|
    stat['source_url'].present? && stat['source'].present?
  }

  new_complete_tools = new_tools.count { |tool|
    tool['url'].present?
  }

  puts "  Examples: #{new_complete_examples}/#{new_examples.size} complete"
  puts "  Statistics: #{new_complete_stats}/#{new_stats.size} with sources"
  puts "  Tools: #{new_complete_tools}/#{new_tools.size} with URLs"
  puts "  Unique companies: #{new_examples.map { |ex| ex['company'] }.compact.uniq.size}"

  puts
  puts "  Sample Examples:"
  new_examples.first(3).each_with_index do |ex, i|
    puts "    #{i+1}. #{ex['company']}"
    puts "       What: #{ex['what_they_did']}"
    puts "       Outcome: #{ex['outcome']&.[](0..80)}..."
    puts "       Source: #{ex['source_url'].present? ? '✅ Has URL' : '❌ Missing URL'}"
  end

  puts
  puts "  Sample Statistics:"
  new_stats.first(3).each_with_index do |stat, i|
    puts "    #{i+1}. #{stat['stat']&.[](0..60)}..."
    puts "       Source: #{stat['source']} (#{stat['year']})"
    puts "       URL: #{stat['source_url'].present? ? '✅ Has URL' : '❌ Missing URL'}"
  end
else
  puts "  (No SERP data)"
end

puts
puts "=" * 80
puts "COMPARISON: OLD vs NEW"
puts "=" * 80
puts

# SERP Data Comparison
if old_serp && new_serp
  puts "SERP DATA IMPROVEMENTS:"
  puts "  Examples: #{old_complete_examples} → #{new_complete_examples} (#{new_complete_examples - old_complete_examples >= 0 ? '+' : ''}#{new_complete_examples - old_complete_examples})"
  puts "  Statistics: #{old_complete_stats} → #{new_complete_stats} (#{new_complete_stats - old_complete_stats >= 0 ? '+' : ''}#{new_complete_stats - old_complete_stats})"
  puts "  Tools: #{old_complete_tools} → #{new_complete_tools} (#{new_complete_tools - old_complete_tools >= 0 ? '+' : ''}#{new_complete_tools - old_complete_tools})"

  old_unique = old_examples.map { |ex| ex['company'] }.compact.uniq.size
  new_unique = new_examples.map { |ex| ex['company'] }.compact.uniq.size
  puts "  Unique companies: #{old_unique} → #{new_unique} (#{new_unique - old_unique >= 0 ? '+' : ''}#{new_unique - old_unique})"
end

puts
puts "ARTICLE CONTENT:"
puts "  Title: #{old_title == article.title ? 'Same' : 'Changed'}"
puts "  Word count: #{old_word_count} → #{article.word_count} (#{article.word_count - old_word_count >= 0 ? '+' : ''}#{article.word_count - old_word_count})"
puts "  Generation cost: $#{article.generation_cost.round(2)}"
puts "  Status: #{article.status}"

puts
puts "=" * 80
puts "QUALITY ASSESSMENT"
puts "=" * 80
puts

if new_complete_examples >= 5 && new_complete_stats >= 10 && new_complete_tools >= 5
  puts "✅ EXCELLENT - High-quality, well-sourced research data"
elsif new_complete_examples >= 3 && new_complete_stats >= 6
  puts "✅ GOOD - Significant improvement over old data"
elsif new_complete_examples >= 2 || new_complete_stats >= 3
  puts "⚠️  FAIR - Some improvement but needs more work"
else
  puts "❌ POOR - Quality issues remain"
end

puts
puts "CONTENT SNIPPET (first 500 chars):"
puts "-" * 80
puts article.content[0..500]
puts "..."
puts "-" * 80

puts
puts "To view full article content:"
puts "  Article.find(14).content"
puts
puts "To view full SERP data:"
puts "  Article.find(14).serp_data"
puts

puts "=" * 80
