# app/services/semantic_similarity_service.rb
# Uses OpenAI embeddings API for semantic similarity calculations
class SemanticSimilarityService
  EMBEDDING_MODEL = "text-embedding-3-small" # Cheaper, faster, good enough for filtering
  EMBEDDING_DIMENSIONS = 1536 # Default dimension for text-embedding-3-small
  OPENAI_EMBEDDINGS_URL = "https://api.openai.com/v1/embeddings"
  MAX_BATCH_SIZE = 2000 # OpenAI limit is 2048, leave buffer

  def initialize
    @api_key = ENV['OPENAI_API_KEY']
    raise "OPENAI_API_KEY environment variable not set" if @api_key.nil? || @api_key.empty?
  end

  # Calculate similarity between two texts
  def similarity(text1, text2)
    embeddings = get_embeddings([text1, text2])
    cosine_similarity(embeddings[0], embeddings[1])
  end

  # Calculate similarity between base text and multiple keywords (batch)
  # Returns array of { keyword: String, similarity: Float }
  def batch_similarity(base_text, keywords)
    return [] if keywords.empty?

    # OpenAI has a limit of 2048 inputs per request
    # So we need to batch if we have more than 2047 keywords (+ 1 for base_text)
    if keywords.size <= MAX_BATCH_SIZE
      # Small enough to do in one request
      all_texts = [base_text] + keywords
      embeddings = get_embeddings(all_texts)
      base_embedding = embeddings[0]

      keywords.each_with_index.map do |keyword, i|
        {
          keyword: keyword,
          similarity: cosine_similarity(base_embedding, embeddings[i + 1])
        }
      end
    else
      # Too many keywords - need to batch
      Rails.logger.info "Batching #{keywords.size} keywords into chunks of #{MAX_BATCH_SIZE}"

      # Get base embedding once
      base_embedding = get_embeddings([base_text])[0]

      # Process keywords in batches
      results = []
      keywords.each_slice(MAX_BATCH_SIZE) do |batch|
        batch_embeddings = get_embeddings(batch)

        batch.each_with_index do |keyword, i|
          results << {
            keyword: keyword,
            similarity: cosine_similarity(base_embedding, batch_embeddings[i])
          }
        end
      end

      results
    end
  end

  # Embed a single text (returns vector array)
  def embed(text)
    get_embeddings([text])[0]
  end

  # Embed multiple texts (returns array of vectors)
  def batch_embed(texts)
    get_embeddings(texts)
  end

  private

  # Call OpenAI embeddings API using HTTP
  def get_embeddings(texts)
    require 'net/http'
    require 'json'

    # Clean texts (remove empty, truncate very long)
    cleaned_texts = texts.map do |text|
      t = text.to_s.strip
      t.empty? ? "unknown" : t[0..8000] # Truncate to ~8K chars (API limit is ~8K tokens)
    end

    # Build request
    uri = URI(OPENAI_EMBEDDINGS_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 30

    request = Net::HTTP::Post.new(uri.path, {
      'Content-Type' => 'application/json',
      'Authorization' => "Bearer #{@api_key}"
    })

    request.body = {
      model: EMBEDDING_MODEL,
      input: cleaned_texts,
      encoding_format: "float"
    }.to_json

    # Make request
    response = http.request(request)

    unless response.is_a?(Net::HTTPSuccess)
      raise "API request failed: #{response.code} - #{response.body}"
    end

    # Parse response
    data = JSON.parse(response.body)
    data["data"].map { |d| d["embedding"] }

  rescue => e
    Rails.logger.error "=" * 100
    Rails.logger.error "CRITICAL: OpenAI Embeddings API FAILED"
    Rails.logger.error "=" * 100
    Rails.logger.error "Error: #{e.class} - #{e.message}"
    Rails.logger.error "Texts count: #{texts.size}"
    Rails.logger.error "First text (#{texts.first.to_s.length} chars): #{texts.first.to_s[0..200]}"
    Rails.logger.error "Backtrace:"
    Rails.logger.error e.backtrace.first(10).join("\n")
    Rails.logger.error "=" * 100
    Rails.logger.error "RETURNING ZERO VECTORS - ALL SIMILARITIES WILL BE 0.0"
    Rails.logger.error "=" * 100

    # Return zero vectors as fallback (will have 0 similarity)
    Array.new(texts.size) { Array.new(EMBEDDING_DIMENSIONS, 0.0) }
  end

  # Calculate cosine similarity between two vectors
  def cosine_similarity(vec1, vec2)
    return 0.0 if vec1.nil? || vec2.nil?
    return 0.0 if vec1.empty? || vec2.empty?
    return 0.0 if vec1.size != vec2.size

    dot_product = vec1.zip(vec2).sum { |a, b| a * b }
    magnitude1 = Math.sqrt(vec1.sum { |a| a**2 })
    magnitude2 = Math.sqrt(vec2.sum { |a| a**2 })

    return 0.0 if magnitude1.zero? || magnitude2.zero?

    dot_product / (magnitude1 * magnitude2)
  end
end
