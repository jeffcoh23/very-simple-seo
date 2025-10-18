#!/usr/bin/env ruby
# Test keyword quality filtering

# These are the actual keywords from Project #25
keywords = [
  "ai-powered customer avatar creator",
  "ai customer segmentation for startups",
  "ai for saving development time",
  "business idea validation",
  "startup idea validation",
  "ai customer personas",
  "customer persona generator"
]

puts "Testing keyword quality filter"
puts "="*80
puts

# Filter criteria
def is_high_quality_keyword?(keyword, domain_title, domain_description)
  # Red flags (filter OUT)
  return false if keyword.match?(/\b(avatar|avatars)\b/i)  # Avatar is not in title/desc
  return false if keyword.match?(/\bsegmentation\b/i)      # Segmentation not core feature
  return false if keyword.match?(/\bfor saving\b|\bsave time\b/i)  # Too generic benefit
  return false if keyword.match?(/\breducing.*risk\b/i)    # Generic benefit, not searchable

  # Must contain at least one core term
  core_terms = %w[validation validate idea business startup customer persona feedback]
  has_core_term = core_terms.any? { |term| keyword.match?(/\b#{term}/i) }

  return false unless has_core_term

  true
end

domain_title = "Business Idea Validation Tool | SignalLab"
domain_desc = "Validate startup ideas with AI-generated customer personas."

puts "Filter results:\n"
keywords.each do |kw|
  result = is_high_quality_keyword?(kw, domain_title, domain_desc)
  status = result ? "✅ KEEP" : "❌ FILTER OUT"
  puts "#{status}: #{kw}"
end
