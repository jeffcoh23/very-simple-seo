class Ai::ClientService
  MODELS = {
    outline_generation: { provider: "anthropic", model: "claude-haiku-4-5" },
    article_writing: { provider: "anthropic", model: "claude-haiku-4-5" },
    article_improvement: { provider: "anthropic", model: "claude-haiku-4-5" },
    keyword_analysis: { provider: "openai", model: "gpt-4o-mini" },
    serp_analysis: { provider: "openai", model: "gpt-4o-mini" },
    grounding_research: { provider: "gemini", model: "gemini-2.5-flash" },
    perplexity_search: { provider: "perplexity", model: "sonar" },
    openai_search: { provider: "openai", model: "gpt-4o" }
  }.freeze

  def initialize(service_name)
    config = MODELS[service_name]
    @provider = config[:provider]
    @model = config[:model]
    @service_name = service_name
  end

  def chat(messages:, max_tokens: nil, temperature: 0.7, system_prompt: nil)
    Rails.logger.info "AI Request: #{@provider}/#{@model} (tokens: #{max_tokens || 'unlimited'})"

    begin
      chat = RubyLLM.chat(
        provider: @provider,
        model: @model,
        assume_model_exists: true
      ).with_temperature(temperature)

      if max_tokens
        case @provider
        when "gemini"
          chat = chat.with_params(generationConfig: {
            maxOutputTokens: max_tokens
          })
        when "perplexity"
          chat = chat.with_params(
            max_tokens: max_tokens,
            return_citations: true,
            return_related_questions: false
          )
        when "openai"
          if @model.start_with?("gpt-5")
            chat = chat.with_params(max_completion_tokens: max_tokens)
          else
            chat = chat.with_params(max_tokens: max_tokens)
          end
        else
          chat = chat.with_params(max_tokens: max_tokens)
        end
      else
        case @provider
        when "perplexity"
          chat = chat.with_params(
            return_citations: true,
            return_related_questions: false
          )
        end
      end

      chat = chat.with_instructions(system_prompt) if system_prompt.present?

      prompt = messages.last[:content]
      response = chat.ask(prompt)

      { success: true, content: response.content, raw_response: response }

    rescue RubyLLM::UnauthorizedError => e
      Rails.logger.error "AI Auth Error: #{e.message}"
      { success: false, error: "Authentication failed" }
    rescue RubyLLM::RateLimitError => e
      Rails.logger.warn "AI Rate Limit: #{e.message}"
      { success: false, error: "Rate limit exceeded" }
    rescue => e
      Rails.logger.error "AI Error: #{e.message}"
      { success: false, error: e.message }
    end
  end

  def chat_with_grounding(messages:, max_tokens: 8000, temperature: 0.3)
    Rails.logger.info "AI Grounding Request: #{@provider}/#{@model} (tokens: #{max_tokens})"

    raise "Grounding only supported with Gemini" unless @provider == "gemini"

    begin
      chat = RubyLLM.chat(provider: @provider, model: @model)
                    .with_temperature(temperature)
                    .with_params(
                      tools: [ { google_search: {} } ],
                      generationConfig: {
                        maxOutputTokens: max_tokens
                      }
                    )

      prompt = messages.last[:content]
      response = chat.ask(prompt)

      { success: true, content: response.content, raw_response: response }

    rescue RubyLLM::UnauthorizedError => e
      Rails.logger.error "AI Auth Error: #{e.message}"
      { success: false, error: "Authentication failed" }
    rescue RubyLLM::RateLimitError => e
      Rails.logger.warn "AI Rate Limit: #{e.message}"
      { success: false, error: "Rate limit exceeded" }
    rescue => e
      Rails.logger.error "AI Error: #{e.message}"
      { success: false, error: e.message }
    end
  end

  def self.for_keyword_analysis
    new(:keyword_analysis)
  end

  def self.for_outline_generation
    new(:outline_generation)
  end

  def self.for_article_writing
    new(:article_writing)
  end

  def self.for_article_improvement
    new(:article_improvement)
  end

  def self.for_serp_analysis
    new(:serp_analysis)
  end

  def self.for_grounding_research
    new(:grounding_research)
  end

  def self.for_perplexity_search
    new(:perplexity_search)
  end

  def self.for_openai_search
    new(:openai_search)
  end
end
