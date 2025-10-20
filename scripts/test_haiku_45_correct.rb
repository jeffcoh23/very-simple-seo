puts "Testing correct Claude Haiku 4.5 model name from Anthropic docs..."
puts

model_name = "claude-haiku-4-5"

puts "Trying: #{model_name}"
begin
  chat = RubyLLM.chat(
    provider: :anthropic,
    model: model_name,
    assume_model_exists: true
  )

  response = chat.ask("Say 'Hello from Haiku 4.5'")
  puts "✅ SUCCESS with #{model_name}"
  puts "Response: #{response.content}"
rescue => e
  puts "❌ FAILED: #{e.message}"
  puts e.backtrace.first(3)
end
