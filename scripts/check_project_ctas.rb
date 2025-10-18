#!/usr/bin/env ruby
require_relative '../config/environment'

project = Project.find(25)
puts "Project: #{project.name}"
puts
puts "CTAs (#{project.ctas&.size || 0}):"
if project.ctas.present?
  project.ctas.each_with_index do |cta, i|
    puts "  #{i+1}. Text: #{cta['cta_text']}"
    puts "     URL: #{cta['cta_url']}"
    puts "     Placement: #{cta['placement']}"
    puts
  end
else
  puts "  (No CTAs configured)"
end
