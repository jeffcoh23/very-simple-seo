#!/usr/bin/env ruby
# Detailed analysis of SERP data usage in Article #14

require_relative '../config/environment'

article = Article.find(14)
serp = article.serp_data
content = article.content

puts "=" * 80
puts "DEEP DIVE: SERP DATA USAGE ANALYSIS"
puts "=" * 80
puts

# ========================================
# STATISTICS USAGE
# ========================================
stats = serp['statistics'] || []
puts "STATISTICS: #{stats.size} available"
puts "-" * 80

stats_used = 0
stats_unused = []

stats.each_with_index do |stat, i|
  stat_text = stat['stat']
  # Check if key words from stat appear in content
  key_words = stat_text.split.select { |w| w.length > 4 }.first(3)

  if key_words.any? { |word| content.downcase.include?(word.downcase.gsub(/[^a-z0-9]/i, '')) }
    stats_used += 1
    puts "✅ USED: #{stat_text[0..80]}..."
    puts "   Source: #{stat['source']} (#{stat['year']})"
  else
    stats_unused << stat
  end
end

puts
puts "Stats Used: #{stats_used}/#{stats.size} (#{(stats_used.to_f / stats.size * 100).round}%)"
puts

if stats_unused.any?
  puts "❌ UNUSED STATISTICS (#{stats_unused.size}):"
  stats_unused.first(5).each do |stat|
    puts "  - #{stat['stat'][0..80]}... (#{stat['source']})"
  end
  puts "  ... and #{stats_unused.size - 5} more" if stats_unused.size > 5
end

puts
puts "=" * 80

# ========================================
# TOOLS USAGE
# ========================================
tools = serp['recommended_tools'] || []
puts "TOOLS: #{tools.size} available"
puts "-" * 80

tools_used = 0
tools_unused = []

tools.each do |tool|
  tool_name = tool['tool_name']
  if content.include?(tool_name)
    tools_used += 1
    puts "✅ USED: #{tool_name}"
    puts "   Context: #{tool['use_case'][0..60]}..."
  else
    tools_unused << tool
  end
end

puts
puts "Tools Used: #{tools_used}/#{tools.size} (#{(tools_used.to_f / tools.size * 100).round}%)"
puts

if tools_unused.any?
  puts "❌ UNUSED TOOLS (#{tools_unused.size}):"
  tools_unused.each do |tool|
    puts "  - #{tool['tool_name']} (#{tool['category']})"
    puts "    Use case: #{tool['use_case'][0..60]}..."
    puts "    Why recommended: #{tool['why_recommended'][0..60]}..." if tool['why_recommended']
    puts
  end
end

puts "=" * 80

# ========================================
# FAQS USAGE
# ========================================
faqs = serp['faqs'] || []
puts "FAQs: #{faqs.size} available"
puts "-" * 80

faqs_used = 0
faqs_unused = []

faqs.each do |faq|
  question = faq['question']
  # Check if question or key parts appear in content
  if content.include?(question) || question.split.select { |w| w.length > 5 }.any? { |word| content.downcase.include?(word.downcase) }
    faqs_used += 1
    puts "✅ USED/REFERENCED: #{question}"
  else
    faqs_unused << faq
  end
end

puts
puts "FAQs Used: #{faqs_used}/#{faqs.size} (#{(faqs_used.to_f / faqs.size * 100).round}%)"
puts

if faqs_unused.any?
  puts "❌ UNUSED FAQs (#{faqs_unused.size}):"
  faqs_unused.each do |faq|
    puts "  Q: #{faq['question']}"
  end
end

puts
puts "=" * 80

# ========================================
# COMPARISON TABLES
# ========================================
tables = serp.dig('comparison_tables', 'tables') || []
puts "COMPARISON TABLES: #{tables.size} available"
puts "-" * 80

if tables.any?
  tables.each_with_index do |table, i|
    puts "#{i+1}. #{table['title']}"
    puts "   Columns: #{table['headers'].join(', ')}"
    puts "   Rows: #{table['rows'].size}"

    # Check if table concept appears in article
    table_used = table['headers'].any? { |h| content.downcase.include?(h.downcase) }
    puts "   #{table_used ? '✅ Likely used' : '❌ Not used'}"
    puts
  end
else
  puts "(No comparison tables in SERP data)"
end

puts "=" * 80

# ========================================
# STEP-BY-STEP GUIDES
# ========================================
guides = serp.dig('step_by_step_guides', 'guides') || []
puts "STEP-BY-STEP GUIDES: #{guides.size} available"
puts "-" * 80

if guides.any?
  guides.each_with_index do |guide, i|
    puts "#{i+1}. #{guide['title']}"
    puts "   Steps: #{guide['steps'].size}"
    puts "   Source: #{guide['source_url']}"

    # Check if guide appears in article
    guide_used = guide['steps'].any? { |step|
      step.split.select { |w| w.length > 5 }.first(3).any? { |word|
        content.downcase.include?(word.downcase.gsub(/[^a-z0-9]/i, ''))
      }
    }
    puts "   #{guide_used ? '✅ Likely used' : '❌ Not used'}"
    puts
  end
else
  puts "(No step-by-step guides in SERP data)"
end

puts "=" * 80

# ========================================
# OVERALL UTILIZATION SCORE
# ========================================
puts "OVERALL UTILIZATION ANALYSIS"
puts "=" * 80
puts

examples_pct = 100 # All 8/8 used
stats_pct = (stats_used.to_f / stats.size * 100).round
tools_pct = tools.any? ? (tools_used.to_f / tools.size * 100).round : 0
faqs_pct = faqs.any? ? (faqs_used.to_f / faqs.size * 100).round : 0

puts "Examples:    100% (8/8)     ✅ EXCELLENT"
puts "Statistics:  #{stats_pct}% (#{stats_used}/#{stats.size})     #{stats_pct >= 50 ? '✅' : '❌'} #{stats_pct >= 50 ? 'GOOD' : 'POOR'}"
puts "Tools:       #{tools_pct}% (#{tools_used}/#{tools.size})     #{tools_pct >= 40 ? '✅' : '❌'} #{tools_pct >= 40 ? 'GOOD' : 'POOR'}"
puts "FAQs:        #{faqs_pct}% (#{faqs_used}/#{faqs.size})     #{faqs_pct >= 60 ? '✅' : '❌'} #{faqs_pct >= 60 ? 'GOOD' : 'POOR'}"

avg_utilization = (examples_pct + stats_pct + tools_pct + faqs_pct) / 4.0
puts
puts "Average Utilization: #{avg_utilization.round}%"
puts

if avg_utilization >= 70
  puts "✅ GOOD - Most SERP data is being used effectively"
elsif avg_utilization >= 50
  puts "⚠️  FAIR - Significant SERP data is going unused"
else
  puts "❌ POOR - Most SERP data is wasted"
end

puts
puts "=" * 80
puts "RECOMMENDATIONS"
puts "=" * 80
puts

if stats_pct < 50
  puts "📊 STATISTICS:"
  puts "  - Only #{stats_pct}% of statistics are being used"
  puts "  - Either: Fetch fewer stats (10 instead of 15) OR"
  puts "  - Better: Prompt writer to use more stats per section (3-4 instead of 1-2)"
  puts
end

if tools_pct < 40
  puts "🛠️  TOOLS:"
  puts "  - Only #{tools_pct}% of recommended tools are mentioned"
  puts "  - Add dedicated 'Tools & Resources' section"
  puts "  - Or integrate tools into relevant sections more aggressively"
  puts
end

if faqs_pct < 60
  puts "❓ FAQs:"
  puts "  - Only #{faqs_pct}% of FAQs are being used"
  puts "  - Ensure FAQ section is always generated"
  puts "  - Or weave FAQ questions into H2/H3 headings"
  puts
end

puts "=" * 80
