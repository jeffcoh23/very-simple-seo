puts "Testing different Claude Haiku 4.5 model name formats..."
puts

# Try different model name formats
model_names = [
  "claude-haiku-4.5",
  "claude-4.5-haiku",
  "claude-4.5-haiku-20251015",
  "claude-haiku-4-5-20251015",
  "claude-3-5-haiku-20241022"  # Try 3.5 Haiku which should exist
]

model_names.each do |model_name|
  puts "Trying: #{model_name}"
  begin
    chat = RubyLLM.chat(
      provider: :anthropic,
      model: model_name,
      assume_model_exists: true
    )

    response = chat.ask("Say 'Hello'")
    puts "  ✓ SUCCESS with #{model_name}"
    puts "  Response: #{response.content[0..50]}"
    break
  rescue => e
    puts "  ✗ FAILED: #{e.message[0..100]}"
  end
  puts
end
