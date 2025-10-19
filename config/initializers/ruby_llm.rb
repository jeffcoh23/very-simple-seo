# config/initializers/ruby_llm.rb
RubyLLM.configure do |config|
  # OpenAI configuration
  config.openai_api_key = ENV["OPENAI_API_KEY"]

  # Gemini configuration
  config.gemini_api_key = ENV["GEMINI_API_KEY"]
end
