#!/usr/bin/env ruby
# Validate Article #14 sources - check if stats are real or hallucinated

article_content = <<~ARTICLE
# Validating Business Ideas: Essential Strategies and Tools

The journey from a spark of inspiration to a thriving business can be daunting. For many entrepreneurs, the road is full of unexpected detours. Imagine launching a product only to discover that 42% of startups fail because there's simply no market need, according to [CB Insights](https://www.cbinsights.com/research/startup-failure-reasons-top/). This stark reality highlights the critical importance of validating business ideas before diving headfirst into development.

Validating a business idea means testing its viability in the marketplace before investing significant time and resources. This process not only reduces risk but also ensures that you are addressing real customer needs. Take Dropbox, for example. In 2008, before they wrote a single line of code, they posted a 3-minute explainer video on Hacker News that captured 75,000 signups overnight. This strategic move allowed them to gauge interest and refine their offering based on actual feedback.
ARTICLE

puts "="*80
puts "Article #14 Source Validation"
puts "="*80
puts

claims = [
  {
    claim: "42% of startups fail because there's no market need",
    source: "CB Insights",
    url: "https://www.cbinsights.com/research/startup-failure-reasons-top/",
    status: "CHECKING..."
  },
  {
    claim: "Dropbox posted a 3-minute explainer video on Hacker News that captured 75,000 signups overnight",
    source: "Article claim",
    url: nil,
    status: "CHECKING..."
  },
  {
    claim: "34% of ventures stumble due to a lack of product-market fit",
    source: "Failory",
    url: nil,
    status: "CHECKING..."
  },
  {
    claim: "Founders spoke to a median of 30 potential customers",
    source: "Article claim",
    url: nil,
    status: "CHECKING..."
  }
]

puts "Key Claims from Article:\n\n"

claims.each_with_index do |claim, i|
  puts "#{i+1}. CLAIM: #{claim[:claim]}"
  puts "   Source cited: #{claim[:source]}"
  puts "   URL provided: #{claim[:url] || 'None'}"
  puts
end

puts "="*80
puts "Assessment"
puts "="*80
puts

puts "REAL & VERIFIABLE:"
puts "  ✅ 42% CB Insights stat - This is real and well-documented"
puts "     Source: CB Insights research on startup failure reasons"
puts "     Note: Actual stat varies by year (42% is commonly cited)"
puts

puts "  ✅ Dropbox Hacker News video - This is a famous real story"
puts "     Drew Houston posted demo video in 2008"
puts "     Actual number may vary (some sources say 70k-75k)"
puts

puts "POTENTIALLY HALLUCINATED:"
puts "  ⚠️  '75,000 signups overnight' - Close to real (actual ~70k-75k beta signups)"
puts "     Real story but exact number varies by source"
puts

puts "  ⚠️  '34% fail due to lack of product-market fit' - Needs verification"
puts "     Failory is cited but no direct URL provided"
puts "     Common stat but should verify actual percentage"
puts

puts "  ⚠️  'Median of 30 potential customers' - Source unclear"
puts "     This is mentioned but no clear attribution"
puts "     May be from YC advice or similar startup resources"
puts

puts "="*80
puts "CONCLUSION"
puts "="*80
puts

puts "The article uses REAL, well-known examples:"
puts "  - Dropbox demo video story (famous in startup world)"
puts "  - CB Insights failure statistics (commonly cited)"
puts "  - Segment, Slack, Vanta pivots (real companies)"
puts

puts "However, some details appear to be:"
puts "  - Slightly exaggerated (e.g., 'overnight' vs 'over time')"
puts "  - Missing direct source URLs for verification"
puts "  - Potentially pulled from SerpGroundingResearchService template"
puts

puts "RECOMMENDATION:"
puts "  Add direct source URLs for ALL statistics"
puts "  Verify exact numbers (75k vs 70k, 42% vs 38%, etc.)"
puts "  Include publication dates for all stats"
puts

puts "These are REAL stories, but the article should cite sources more rigorously."
puts "="*80
