#!/usr/bin/env ruby
# Fix SignalLab project CTAs

require_relative '../config/environment'

project = Project.find(25)

puts "=" * 80
puts "FIXING SIGNALLAB CTAs"
puts "=" * 80
puts
puts "Current CTAs:"
puts project.call_to_actions.inspect
puts

# Add proper CTAs based on SignalLab site
new_ctas = [
  {
    "text" => "Try SignalLab Free",
    "url" => "https://signallab.app/signup"
  },
  {
    "text" => "See Pricing Plans",
    "url" => "https://signallab.app/pricing"
  }
]

project.update!(call_to_actions: new_ctas)

puts "✅ Updated CTAs:"
puts project.call_to_actions.inspect
puts
puts "=" * 80
puts "NEXT STEP: Regenerate Article #14"
puts "=" * 80
puts
puts "The article should now include:"
puts "- 2-5 SignalLab brand mentions"
puts "- Real CTAs (not example.com)"
puts "- Real internal links from sitemap"
puts
puts "Run: bin/rails runner scripts/regenerate_article_14.rb"
puts "=" * 80
