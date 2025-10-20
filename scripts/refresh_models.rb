puts "Refreshing RubyLLM model registry..."
RubyLLM::Models.refresh_registry!
puts "✓ Registry refreshed!"
puts
puts "Testing if claude-haiku-4.5 is now available..."
begin
  chat = RubyLLM.chat(provider: :anthropic, model: "claude-haiku-4.5")
  puts "✓ claude-haiku-4.5 is available!"
rescue => e
  puts "✗ Error: #{e.message}"
end
