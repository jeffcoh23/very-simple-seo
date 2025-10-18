#!/usr/bin/env ruby
# Full quality review of Article #14

require_relative '../config/environment'

article = Article.find(14)

puts "=" * 80
puts "ARTICLE #14 - COMPREHENSIVE QUALITY REVIEW"
puts "=" * 80
puts
puts "Title: #{article.title}"
puts "Meta Description: #{article.meta_description}"
puts "Word Count: #{article.word_count}"
puts "Generation Cost: $#{article.generation_cost.round(2)}"
puts

puts "=" * 80
puts "FULL ARTICLE CONTENT"
puts "=" * 80
puts
puts article.content
puts
puts "=" * 80
puts "QUALITY ANALYSIS"
puts "=" * 80
puts

# Check for SignalLab mentions
signallab_mentions = article.content.scan(/SignalLab/i).size
validatorai_mentions = article.content.scan(/ValidatorAI/i).size

puts "Brand Mentions:"
puts "  SignalLab: #{signallab_mentions} times"
puts "  ValidatorAI: #{validatorai_mentions} times #{validatorai_mentions > 0 ? '⚠️  PROBLEM!' : '✅'}"
puts

# Check for external links
external_links = article.content.scan(/\[.*?\]\((https?:\/\/.*?)\)/)
internal_links = article.content.scan(/\[.*?\]\((\/.*?)\)/)

puts "Links:"
puts "  External sources: #{external_links.size}"
puts "  Internal links: #{internal_links.size}"
puts

if external_links.any?
  puts "  Sample external sources:"
  external_links.first(5).each do |link|
    puts "    - #{link.first}"
  end
end

puts

# Check for placeholder content
placeholders = []
placeholders << "TODO" if article.content.include?("TODO")
placeholders << "[Your Site]" if article.content.include?("[Your Site]")
placeholders << "example.com" if article.content.include?("example.com")
placeholders << "yourdomain.com" if article.content.include?("yourdomain.com")

if placeholders.any?
  puts "❌ PLACEHOLDERS FOUND: #{placeholders.join(', ')}"
else
  puts "✅ No placeholders detected"
end

puts

# Check structure
has_sections = article.content.include?("##")
has_introduction = article.content.split("##").first.split.size > 100
has_conclusion = article.content.downcase.include?("conclusion") || article.content.downcase.include?("final thoughts")

puts "Article Structure:"
puts "  Has sections (##): #{has_sections ? '✅' : '❌'}"
puts "  Has substantial intro: #{has_introduction ? '✅' : '❌'}"
puts "  Has conclusion: #{has_conclusion ? '✅' : '❌'}"

puts
puts "=" * 80
puts "SERP DATA USED"
puts "=" * 80
puts

serp_data = article.serp_data
if serp_data
  examples = serp_data['detailed_examples'] || []
  stats = serp_data['statistics'] || []
  tools = serp_data['recommended_tools'] || []
  faqs = serp_data['faqs'] || []

  puts "Examples in SERP data: #{examples.size}"
  puts "Statistics in SERP data: #{stats.size}"
  puts "Tools in SERP data: #{tools.size}"
  puts "FAQs in SERP data: #{faqs.size}"

  # Check if examples are actually used in content
  examples_used = examples.select { |ex|
    article.content.include?(ex['company']) if ex['company'].present?
  }.size

  puts
  puts "Examples actually used in article: #{examples_used}/#{examples.size}"

  # Check if stats are used
  stats_used = 0
  stats.each do |stat|
    # Check if the statistic appears in content
    if stat['stat'] && article.content.include?(stat['stat'].split.first(5).join(' '))
      stats_used += 1
    end
  end

  puts "Statistics actually used in article: ~#{stats_used}/#{stats.size} (approximate)"
end

puts
puts "=" * 80
puts "OVERALL VERDICT"
puts "=" * 80
puts

score = 0
issues = []
strengths = []

# Scoring
if signallab_mentions > 0
  score += 15
  strengths << "Mentions SignalLab (#{signallab_mentions}x)"
else
  issues << "No SignalLab mentions"
end

if validatorai_mentions == 0
  score += 15
  strengths << "No competitor mentions"
else
  issues << "Still mentions ValidatorAI"
end

if external_links.size >= 5
  score += 20
  strengths << "Well-sourced (#{external_links.size} external links)"
elsif external_links.size >= 3
  score += 10
  strengths << "Some sources (#{external_links.size} links)"
else
  issues << "Insufficient external sources"
end

if placeholders.empty?
  score += 15
  strengths << "No placeholders"
else
  issues << "Contains placeholders: #{placeholders.join(', ')}"
end

if has_sections && has_introduction && has_conclusion
  score += 15
  strengths << "Good structure (intro, sections, conclusion)"
elsif has_sections
  score += 8
  strengths << "Has sections but missing intro/conclusion"
else
  issues << "Poor structure"
end

if article.word_count >= 2500
  score += 10
  strengths << "Good length (#{article.word_count} words)"
elsif article.word_count >= 2000
  score += 5
  strengths << "Decent length (#{article.word_count} words)"
else
  issues << "Too short (#{article.word_count} words)"
end

if examples_used && examples_used >= 3
  score += 10
  strengths << "Uses real examples (#{examples_used} examples)"
elsif examples_used && examples_used >= 1
  score += 5
  strengths << "Uses some examples (#{examples_used})"
else
  issues << "Doesn't use SERP examples"
end

puts "SCORE: #{score}/100"
puts

if score >= 80
  puts "✅ EXCELLENT - Ready to publish"
elsif score >= 60
  puts "✅ GOOD - Minor improvements needed"
elsif score >= 40
  puts "⚠️  FAIR - Needs work before publishing"
else
  puts "❌ POOR - Major issues to fix"
end

puts
puts "STRENGTHS:"
strengths.each { |s| puts "  ✅ #{s}" }

if issues.any?
  puts
  puts "ISSUES TO FIX:"
  issues.each { |i| puts "  ❌ #{i}" }
end

puts
puts "=" * 80
