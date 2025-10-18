#!/usr/bin/env ruby
require_relative '../config/environment'

project = Project.find(25)
puts "=" * 80
puts "DIAGNOSING INTERNAL LINK PROBLEM"
puts "=" * 80
puts
puts "Project: #{project.name}"
puts "Domain: #{project.domain}"
puts
puts "Completed articles in DB: #{project.articles.where(status: :completed).count}"
puts
puts "Sample internal links being suggested:"
articles = project.articles.where(status: :completed).order(created_at: :desc).limit(5)
articles.each do |a|
  puts "  ❌ /articles/#{a.id} - #{a.title}"
  puts "     (This is a database path, not a real published URL!)"
end
puts
puts "=" * 80
puts "THE PROBLEM"
puts "=" * 80
puts
puts "❌ Using database article IDs: /articles/123"
puts "❌ These URLs don't exist on your live site"
puts "❌ AI is suggesting links to pages that don't exist"
puts "❌ No actual published blog posts being discovered"
puts
puts "=" * 80
puts "WHAT SHOULD HAPPEN INSTEAD"
puts "=" * 80
puts
puts "✅ Scrape sitemap.xml: #{project.sitemap_url || project.domain + '/sitemap.xml'}"
puts "✅ Discover REAL published URLs like:"
puts "   - https://signallab.app/blog/validate-business-ideas"
puts "   - https://signallab.app/pricing"
puts "   - https://signallab.app/features/ai-personas"
puts "   - https://signallab.app/guides/customer-interviews"
puts
puts "✅ Extract page metadata from live HTML:"
puts "   - Title, meta description, headings"
puts "   - Actual content topics"
puts "   - Current/accurate information"
puts
puts "=" * 80
puts "IMPACT OF CURRENT APPROACH"
puts "=" * 80
puts
puts "❌ BROKEN LINKS: Articles suggest linking to /articles/123 (404s)"
puts "❌ MISSED OPPORTUNITIES: Real blog posts/pages aren't discovered"
puts "❌ INCOMPLETE CONTEXT: AI doesn't know about pricing, features, guides"
puts "❌ STALE DATA: Only knows about articles generated in THIS app"
puts
puts "If you have a blog at #{project.domain}/blog, we're not finding it!"
puts "If you have pricing at #{project.domain}/pricing, we're not linking to it!"
puts
puts "=" * 80
