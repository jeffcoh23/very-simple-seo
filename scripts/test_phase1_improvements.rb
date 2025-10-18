#!/usr/bin/env ruby
# Test Phase 1 brand integration improvements on Article #14

require_relative '../config/environment'

article = Article.find(14)
project = article.project

puts "=" * 80
puts "TESTING PHASE 1: BRAND INTEGRATION IMPROVEMENTS"
puts "=" * 80
puts
puts "Article: #{article.title}"
puts "Project: #{project.name}"
puts "Domain: #{project.domain}"
puts
puts "Project CTAs configured: #{project.call_to_actions&.size || 0}"
if project.call_to_actions&.any?
  project.call_to_actions.each_with_index do |cta, i|
    puts "  #{i+1}. #{cta['cta_text']} → #{cta['cta_url']}"
  end
end
puts
puts "=" * 80
puts "REGENERATING ARTICLE WITH BRAND IMPROVEMENTS..."
puts "=" * 80
puts

# Regenerate the article
service = ArticleGenerationService.new(article)
service.perform

# Reload to get fresh content
article.reload

puts
puts "=" * 80
puts "REGENERATION COMPLETE"
puts "=" * 80
puts

# Analyze brand integration
brand_mentions = article.content.scan(/#{Regexp.escape(project.name)}/i).size
has_example_com = article.content.include?('example.com')
has_real_domain = article.content.include?(project.domain.gsub('https://', '').gsub('http://', ''))

puts "BRAND INTEGRATION ANALYSIS:"
puts "  #{project.name} mentions: #{brand_mentions}"
puts "  Contains example.com: #{has_example_com ? '❌ YES' : '✅ NO'}"
puts "  Contains #{project.domain}: #{has_real_domain ? '✅ YES' : '❌ NO'}"
puts

# Extract CTAs from content
cta_links = article.content.scan(/\[([^\]]+)\]\(([^)]+)\)/).select { |text, url|
  url.include?('signup') || url.include?('trial') || url.include?(project.domain.gsub('https://', '').gsub('http://', ''))
}

puts "CTAs FOUND IN CONTENT:"
if cta_links.any?
  cta_links.each_with_index do |(text, url), i|
    puts "  #{i+1}. [#{text}](#{url})"
  end
else
  puts "  (None found)"
end

puts
puts "=" * 80
puts "QUALITY SCORE"
puts "=" * 80
puts

score = 0
issues = []
improvements = []

# Brand mentions (20 points)
if brand_mentions >= 2 && brand_mentions <= 5
  score += 20
  improvements << "Good brand integration (#{brand_mentions} mentions)"
elsif brand_mentions > 0
  score += 10
  improvements << "Has brand mentions (#{brand_mentions})"
else
  issues << "No brand mentions"
end

# Real CTAs (20 points)
if !has_example_com && has_real_domain
  score += 20
  improvements << "Real CTAs (no placeholders)"
elsif has_real_domain
  score += 15
  improvements << "Has real domain CTAs"
else
  issues << "Still has placeholder CTAs"
end

# CTA placement (10 points)
if cta_links.size >= 2
  score += 10
  improvements << "Multiple CTAs placed (#{cta_links.size})"
elsif cta_links.size == 1
  score += 5
  improvements << "At least one CTA"
else
  issues << "No CTAs found in content"
end

# SERP data (50 points - should maintain)
examples = article.serp_data['detailed_examples']&.size || 0
stats = article.serp_data['statistics']&.size || 0

if examples >= 8 && stats >= 15
  score += 50
  improvements << "Excellent SERP data (#{examples} examples, #{stats} stats)"
elsif examples >= 5 && stats >= 10
  score += 35
  improvements << "Good SERP data"
else
  score += 20
  issues << "Insufficient SERP data"
end

puts "SCORE: #{score}/100"
puts

if score >= 85
  puts "✅ EXCELLENT - Ready for production"
elsif score >= 70
  puts "✅ GOOD - Minor improvements possible"
elsif score >= 50
  puts "⚠️  FAIR - Needs some work"
else
  puts "❌ POOR - Major issues"
end

puts
puts "IMPROVEMENTS:"
improvements.each { |imp| puts "  ✅ #{imp}" }

if issues.any?
  puts
  puts "ISSUES:"
  issues.each { |iss| puts "  ❌ #{iss}" }
end

puts
puts "=" * 80
puts "CONTENT PREVIEW (first 800 chars)"
puts "=" * 80
puts article.content[0..800]
puts "..."
puts "=" * 80
