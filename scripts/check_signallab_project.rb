#!/usr/bin/env ruby
# Check what's actually stored in SignalLab project

require_relative '../config/environment'

puts "="*80
puts "SignalLab Project Stored Data"
puts "="*80

# Find SignalLab project
project = Project.find_by(domain: "https://signallab.app") ||
          Project.find_by("domain LIKE ?", "%signallab%")

if project
  puts "\nProject found: #{project.name}"
  puts "Domain: #{project.domain}"
  puts "Created: #{project.created_at}"
  puts "Updated: #{project.updated_at}"

  puts "\n--- Stored Seed Keywords ---"
  if project.seed_keywords.present?
    keywords = project.seed_keywords.is_a?(Array) ? project.seed_keywords : project.seed_keywords.split("\n")
    keywords.each_with_index do |kw, i|
      # Flag weird ones
      if kw.match?(/avatar|segmentation/i)
        puts "  #{i+1}. #{kw} ← 🚩 WEIRD"
      else
        puts "  #{i+1}. #{kw}"
      end
    end
    puts "\nTotal: #{keywords.size} keywords"
  else
    puts "  (No seed keywords stored)"
  end

  puts "\n--- Stored Competitors ---"
  if project.competitors.any?
    project.competitors.each_with_index do |comp, i|
      puts "  #{i+1}. #{comp.domain}"
    end
    puts "\nTotal: #{project.competitors.count} competitors"
  else
    puts "  (No competitors stored)"
  end

  puts "\n--- Domain Analysis Data ---"
  if project.domain_analysis.present?
    puts "  Title: #{project.domain_analysis['title']}"
    puts "  Meta: #{project.domain_analysis['meta_description']}"
  else
    puts "  (No domain analysis stored)"
  end
else
  puts "\n❌ No SignalLab project found in database"
  puts "\nAll projects:"
  Project.limit(5).each do |p|
    puts "  - #{p.name} (#{p.domain})"
  end
end

puts "\n" + "="*80
