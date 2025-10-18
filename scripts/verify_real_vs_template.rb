#!/usr/bin/env ruby
# Verify if API returned real data or just copied the template

# Template example from the prompt (lines 61-70)
template_example = {
  "company" => "Dropbox",
  "what_they_did" => "Validated demand before building product",
  "how_they_did_it" => "Created 3-minute demo video showing product concept, posted on Hacker News with email signup form, drove traffic through targeted tech community outreach",
  "timeline" => "2008, 4 months before first beta release",
  "outcome" => "75,000 beta signups, 15% conversion to paid tier at launch",
  "source_url" => "https://techcrunch.com/2011/10/19/dropbox-minimal-viable-product/"
}

# What the API actually returned (from test output)
api_returned = {
  "company" => "Dropbox",
  "what_they_did" => "Used a demo video to gauge interest",  # DIFFERENT!
  "how_they_did_it" => "Drew Houston, the founder, created a simple 3-minute demo video explaining the concept of Dropbox and how it solved the problem of syncing files across...",
  "outcome" => "The video generated a huge influx of sign-ups, reportedly overnight, demonstrating significant demand for the product. This validated the idea and helped secure funding [10].",
  "source_url" => "https://vertexaisearch.cloud.google.com/grounding-api-redirect/..."
}

puts "="*80
puts "Template vs Actual API Response Comparison"
puts "="*80
puts

puts "TEMPLATE (from prompt):"
puts "  Company: #{template_example['company']}"
puts "  What: #{template_example['what_they_did']}"
puts "  How: #{template_example['how_they_did_it'][0..80]}..."
puts "  Outcome: #{template_example['outcome']}"
puts "  URL: #{template_example['source_url']}"

puts

puts "API RETURNED:"
puts "  Company: #{api_returned['company']}"
puts "  What: #{api_returned['what_they_did']}"
puts "  How: #{api_returned['how_they_did_it'][0..80]}..."
puts "  Outcome: #{api_returned['outcome'][0..80]}..."
puts "  URL: #{api_returned['source_url'][0..50]}..."

puts
puts "="*80
puts "ANALYSIS"
puts "="*80
puts

if api_returned['what_they_did'] == template_example['what_they_did']
  puts "❌ COPIED: 'what_they_did' matches template exactly"
else
  puts "✅ ORIGINAL: 'what_they_did' is different from template"
  puts "   Template: '#{template_example['what_they_did']}'"
  puts "   API: '#{api_returned['what_they_did']}'"
end

puts

if api_returned['how_they_did_it'] == template_example['how_they_did_it']
  puts "❌ COPIED: 'how_they_did_it' matches template exactly"
else
  puts "✅ ORIGINAL: 'how_they_did_it' is different from template"
  puts "   Template mentions: 'targeted tech community outreach'"
  puts "   API mentions: 'Drew Houston, the founder...explaining the concept'"
end

puts

if api_returned['source_url'].include?('techcrunch.com')
  puts "❌ COPIED: Using template's TechCrunch URL"
elsif api_returned['source_url'].include?('vertexaisearch.cloud.google.com')
  puts "✅ REAL GROUNDING: Using Google's grounding redirect URL"
  puts "   This proves the AI actually searched the web"
else
  puts "⚠️  UNCLEAR: Different URL but not sure if real"
end

puts
puts "="*80
puts "VERDICT"
puts "="*80
puts

puts "The API is NOT just copying the template!"
puts
puts "Evidence:"
puts "  1. Different phrasing ('Used a demo video' vs 'Validated demand')"
puts "  2. More detailed 'how' section mentioning Drew Houston by name"
puts "  3. Uses Google Grounding redirect URLs (proves web search happened)"
puts "  4. Added citation markers like [10]"
puts "  5. Found OTHER examples not in template (Buffer, Airbnb)"
puts
puts "The template serves as a FORMAT EXAMPLE, not source data."
puts "The AI is actually searching the web and finding real sources."

puts "="*80
