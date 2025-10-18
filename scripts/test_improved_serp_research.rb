#!/usr/bin/env ruby
# Test the improved SERP research service

require_relative '../config/environment'

keyword = "validating business ideas"
project = Project.find(25) # SignalLab

puts "="*80
puts "Testing Improved SERP Research Service"
puts "="*80
puts
puts "Keyword: #{keyword}"
puts "Project: #{project.name}"
puts

puts "Running research (this will take ~30-60 seconds for 3 API calls)..."
puts

service = SerpGroundingResearchService.new(keyword, project: project)
result = service.perform

if result[:data]
  data = result[:data]

  puts "="*80
  puts "RESULTS"
  puts "="*80
  puts

  puts "--- EXAMPLES (#{data['detailed_examples']&.size || 0}) ---"
  if data['detailed_examples']&.any?
    data['detailed_examples'].first(3).each_with_index do |ex, i|
      puts "\n#{i+1}. #{ex['company']}"
      puts "   What: #{ex['what_they_did']}"
      puts "   How: #{ex['how_they_did_it']&.[](0..150)}..."
      puts "   Outcome: #{ex['outcome']}"
      puts "   Source: #{ex['source_url']}"

      # Validation checks
      if ex['source_url'].blank?
        puts "   ❌ MISSING SOURCE URL"
      elsif ex['outcome'].blank?
        puts "   ❌ MISSING OUTCOME"
      elsif ex['how_they_did_it'].blank? || ex['how_they_did_it'].length < 50
        puts "   ⚠️  HOW details too short"
      else
        puts "   ✅ Complete"
      end
    end

    if data['detailed_examples'].size > 3
      puts "\n... and #{data['detailed_examples'].size - 3} more examples"
    end
  else
    puts "  (No examples found)"
  end

  puts "\n--- STATISTICS (#{data['statistics']&.size || 0}) ---"
  if data['statistics']&.any?
    data['statistics'].first(5).each_with_index do |stat, i|
      puts "\n#{i+1}. #{stat['stat']}"
      puts "   Source: #{stat['source']} (#{stat['year']})"
      puts "   URL: #{stat['source_url']}"

      # Validation checks
      if stat['source_url'].blank?
        puts "   ❌ MISSING SOURCE URL"
      elsif stat['source'].blank?
        puts "   ❌ MISSING SOURCE"
      else
        puts "   ✅ Complete"
      end
    end

    if data['statistics'].size > 5
      puts "\n... and #{data['statistics'].size - 5} more stats"
    end
  else
    puts "  (No statistics found)"
  end

  puts "\n--- TOOLS (#{data['recommended_tools']&.size || 0}) ---"
  if data['recommended_tools']&.any?
    data['recommended_tools'].first(3).each_with_index do |tool, i|
      puts "\n#{i+1}. #{tool['tool_name']} (#{tool['category']})"
      puts "   Use case: #{tool['use_case']}"
      puts "   Pricing: #{tool['pricing']}"
      puts "   URL: #{tool['url']}"

      # Validation checks
      if tool['url'].blank?
        puts "   ❌ MISSING URL"
      else
        puts "   ✅ Complete"
      end
    end

    if data['recommended_tools'].size > 3
      puts "\n... and #{data['recommended_tools'].size - 3} more tools"
    end
  else
    puts "  (No tools found)"
  end

  puts "\n--- FAQs (#{data['faqs']&.size || 0}) ---"
  if data['faqs']&.any?
    puts data['faqs'].first(3).map.with_index { |faq, i| "#{i+1}. #{faq['question']}" }.join("\n")
    if data['faqs'].size > 3
      puts "... and #{data['faqs'].size - 3} more FAQs"
    end
  else
    puts "  (No FAQs found)"
  end

  puts "\n--- GUIDES (#{data['step_by_step_guides']['guides']&.size || 0}) ---"
  if data['step_by_step_guides']['guides']&.any?
    data['step_by_step_guides']['guides'].first(2).each_with_index do |guide, i|
      puts "\n#{i+1}. #{guide['title']}"
      puts "   Steps: #{guide['steps']&.size || 0}"
      puts "   Source: #{guide['source_url']}"
    end
  else
    puts "  (No guides found)"
  end

  puts "\n" + "="*80
  puts "QUALITY ASSESSMENT"
  puts "="*80
  puts

  # Count items with complete data
  complete_examples = data['detailed_examples']&.count { |ex|
    ex['source_url'].present? && ex['outcome'].present? &&
    ex['how_they_did_it'].present? && ex['how_they_did_it'].length > 50
  } || 0

  complete_stats = data['statistics']&.count { |stat|
    stat['source_url'].present? && stat['source'].present?
  } || 0

  complete_tools = data['recommended_tools']&.count { |tool|
    tool['url'].present? && tool['tool_name'].present?
  } || 0

  total_examples = data['detailed_examples']&.size || 0
  total_stats = data['statistics']&.size || 0
  total_tools = data['recommended_tools']&.size || 0

  puts "Examples: #{complete_examples}/#{total_examples} complete (#{total_examples > 0 ? (complete_examples.to_f / total_examples * 100).round : 0}%)"
  puts "Statistics: #{complete_stats}/#{total_stats} with sources (#{total_stats > 0 ? (complete_stats.to_f / total_stats * 100).round : 0}%)"
  puts "Tools: #{complete_tools}/#{total_tools} with URLs (#{total_tools > 0 ? (complete_tools.to_f / total_tools * 100).round : 0}%)"

  puts

  if complete_examples >= 5 && complete_stats >= 8 && complete_tools >= 4
    puts "✅ GREAT RESULTS - High quality, well-sourced data"
  elsif complete_examples >= 3 && complete_stats >= 5
    puts "✅ GOOD RESULTS - Usable data with most sources"
  elsif complete_examples >= 2 || complete_stats >= 3
    puts "⚠️  FAIR RESULTS - Some usable data but needs improvement"
  else
    puts "❌ POOR RESULTS - Insufficient quality data"
  end

  puts
  puts "Cost: $#{sprintf('%.2f', result[:cost])}"

else
  puts "❌ Research failed - no data returned"
end

puts "="*80
