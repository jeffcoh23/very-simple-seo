# app/services/keyword_clustering_service.rb
# Clusters similar keywords together to avoid duplicate content
# Groups "business ai tool" and "business ai tools" into one cluster
class KeywordClusteringService
  # Minimum similarity to consider keywords as duplicates
  SIMILARITY_THRESHOLD = 0.85 # High threshold - only cluster very similar keywords

  def initialize(keywords_with_data)
    # keywords_with_data is a hash: { "keyword" => { volume: 100, difficulty: 50, ... } }
    @keywords_with_data = keywords_with_data
    @similarity_service = SemanticSimilarityService.new
  end

  # Cluster keywords and return best representative from each cluster
  # Returns: { "keyword" => { ...data..., cluster_size: 3 } }
  def cluster_and_select_best
    return {} if @keywords_with_data.empty?

    Rails.logger.info "Clustering #{@keywords_with_data.size} keywords..."

    # Step 1: Calculate pairwise similarities between all keywords
    clusters = build_clusters

    # Step 2: Select best keyword from each cluster
    best_keywords = select_best_from_clusters(clusters)

    Rails.logger.info "Clustered into #{clusters.size} groups, selected #{best_keywords.size} representatives"

    best_keywords
  end

  private

  def build_clusters
    keywords = @keywords_with_data.keys
    return [] if keywords.empty?

    # Start with each keyword in its own cluster
    clusters = keywords.map { |kw| [kw] }

    # Get embeddings for all keywords at once (efficient batch processing)
    embeddings_map = {}
    keywords.each_slice(2000) do |batch|
      batch_embeddings = @similarity_service.batch_embed(batch)
      batch.each_with_index do |kw, i|
        embeddings_map[kw] = batch_embeddings[i]
      end
    end

    # Merge similar clusters iteratively
    merged = true
    iterations = 0
    max_iterations = 100 # Prevent infinite loops

    while merged && iterations < max_iterations
      merged = false
      iterations += 1

      # Try to merge clusters
      i = 0
      while i < clusters.size
        j = i + 1
        while j < clusters.size
          # Check if any keyword in cluster i is similar to any in cluster j
          if clusters_similar?(clusters[i], clusters[j], embeddings_map)
            # Merge cluster j into cluster i
            clusters[i].concat(clusters[j])
            clusters.delete_at(j)
            merged = true
          else
            j += 1
          end
        end
        i += 1
      end
    end

    Rails.logger.info "Clustering converged after #{iterations} iterations"
    clusters
  end

  # Check if two clusters have any keywords that are very similar
  def clusters_similar?(cluster1, cluster2, embeddings_map)
    # For efficiency, just check first keyword of each cluster
    # (since keywords in same cluster are already similar)
    kw1 = cluster1.first
    kw2 = cluster2.first

    embedding1 = embeddings_map[kw1]
    embedding2 = embeddings_map[kw2]

    return false if embedding1.nil? || embedding2.nil?

    similarity = @similarity_service.send(:cosine_similarity, embedding1, embedding2)
    similarity >= SIMILARITY_THRESHOLD
  end

  def select_best_from_clusters(clusters)
    best_keywords = {}

    clusters.each do |cluster|
      # Select best keyword from this cluster based on:
      # 1. Highest volume (most important)
      # 2. Highest opportunity (if volume is similar)
      # 3. Shortest keyword (tiebreaker - more focused)

      best_keyword = cluster.max_by do |kw|
        data = @keywords_with_data[kw]
        volume = data[:volume] || 0
        opportunity = data[:opportunity] || 0
        length_penalty = -kw.length * 0.01 # Slight preference for shorter keywords

        # Score: volume is most important, opportunity breaks ties
        (volume * 1000) + opportunity + length_penalty
      end

      # Add cluster metadata
      best_data = @keywords_with_data[best_keyword].dup
      best_data[:cluster_size] = cluster.size
      best_data[:cluster_keywords] = cluster - [best_keyword] # Other keywords in cluster

      best_keywords[best_keyword] = best_data

      if cluster.size > 1
        Rails.logger.info "  Cluster (#{cluster.size}): #{best_keyword} ← [#{cluster[1..3].join(', ')}#{cluster.size > 4 ? '...' : ''}]"
      end
    end

    best_keywords
  end
end
