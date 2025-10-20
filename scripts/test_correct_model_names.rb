puts "Testing correct model names from API docs..."
puts "=" * 80
puts

models_to_test = [
  { name: "GPT-5 (dated)", provider: :openai, model: "gpt-5-2025-08-07" },
  { name: "GPT-5 (simple)", provider: :openai, model: "gpt-5" },
  { name: "GPT-5-mini (dated)", provider: :openai, model: "gpt-5-mini-2025-08-07" },
  { name: "GPT-5-mini (simple)", provider: :openai, model: "gpt-5-mini" },
  { name: "Gemini 2.5 Pro", provider: :gemini, model: "gemini-2.5-pro" },
  { name: "Gemini 2.0 Flash", provider: :gemini, model: "gemini-2.0-flash-exp" }
]

models_to_test.each do |config|
  puts "Testing: #{config[:name]}"
  puts "  Provider: #{config[:provider]}"
  puts "  Model: #{config[:model]}"

  begin
    chat = RubyLLM.chat(
      provider: config[:provider],
      model: config[:model],
      assume_model_exists: true
    )

    response = chat.ask("Say 'Hello from #{config[:name]}'")
    puts "  ✅ SUCCESS"
    puts "  Response: #{response.content[0..80]}"
  rescue => e
    puts "  ❌ FAILED"
    puts "  Error: #{e.message[0..200]}"
  end

  puts
end

puts "=" * 80
puts "Test complete!"
