#!/usr/bin/env ruby
# Debug why SignalLab is getting weird keywords

require_relative '../config/environment'

domain = "https://signallab.app"

puts "="*80
puts "DEBUG: Why is SignalLab getting weird keywords?"
puts "="*80

# Step 1: Analyze domain
analyzer = DomainAnalysisService.new(domain)
domain_data = analyzer.analyze

puts "\n--- Domain Data Being Used ---"
puts "Domain: #{domain}"
puts "Title: #{domain_data[:title]}"
puts "Meta Description: #{domain_data[:meta_description]}"
puts "H1s: #{domain_data[:h1s]&.inspect}"
puts "H2s: #{domain_data[:h2s]&.inspect}"

# Step 2: Get competitors (using hybrid approach)
service = AutofillProjectService.new(domain)
result = service.perform
competitors = result[:competitors]

puts "\n--- Competitors Being Used ---"
competitors.each_with_index do |c, i|
  puts "#{i+1}. #{c[:domain]}"
end

# Step 3: Check what OpenAI is generating
puts "\n" + "="*80
puts "OpenAI Keyword Prompt Analysis"
puts "="*80

competitor_list = competitors.map { |c| c[:domain] }.join(", ")

puts "\nPrompt context being sent to OpenAI:"
puts "  Domain: #{domain}"
puts "  Title: #{domain_data[:title]}"
puts "  Meta Desc: #{domain_data[:meta_description]}"
puts "  H1s: #{domain_data[:h1s]&.join(', ')}"
puts "  H2s (first 5): #{domain_data[:h2s]&.first(5)&.join(', ')}"
puts "  Competitors: #{competitor_list}"

# Step 4: Generate keywords and check results
puts "\n--- Actual Keywords Generated ---"
openai_keywords = service.send(:generate_seeds_via_openai, domain_data, competitors)

puts "\nOpenAI Keywords (#{openai_keywords.size}):"
openai_keywords.each_with_index do |kw, i|
  # Flag weird ones
  is_weird = false
  reason = nil

  if kw.match?(/avatar|segmentation|saving development/i)
    is_weird = true
    reason = "← 🚩 WEIRD"
  elsif kw.match?(/customer persona|validation|startup idea/i)
    reason = "← ✅ GOOD"
  end

  puts "  #{i+1}. #{kw} #{reason}"
end

puts "\n--- Grounding Keywords ---"
grounding_keywords = service.send(:generate_seeds_via_grounding, domain_data, competitors)

puts "\nGrounding Keywords (#{grounding_keywords.size}):"
grounding_keywords.each_with_index do |kw, i|
  # Flag weird ones
  is_weird = false
  reason = nil

  if kw.match?(/avatar|segmentation|saving development/i)
    is_weird = true
    reason = "← 🚩 WEIRD"
  elsif kw.match?(/customer persona|validation|startup idea/i)
    reason = "← ✅ GOOD"
  end

  puts "  #{i+1}. #{kw} #{reason}"
end

# Step 5: Check if weird keywords are in meta description
puts "\n" + "="*80
puts "Root Cause Analysis"
puts "="*80

meta_desc = domain_data[:meta_description] || ""
title = domain_data[:title] || ""

puts "\nChecking if weird keywords come from domain content:"

if meta_desc.match?(/customer persona/i)
  puts "  ✅ 'customer persona' is in meta description"
end

if meta_desc.match?(/avatar/i)
  puts "  🚩 'avatar' is in meta description"
else
  puts "  ℹ️  'avatar' is NOT in meta description - AI hallucination?"
end

if meta_desc.match?(/segmentation/i)
  puts "  🚩 'segmentation' is in meta description"
else
  puts "  ℹ️  'segmentation' is NOT in meta description - AI hallucination?"
end

if meta_desc.match?(/saving.*development.*time|save.*development/i)
  puts "  ✅ 'saving development time' is in meta description"
end

puts "\n" + "="*80
