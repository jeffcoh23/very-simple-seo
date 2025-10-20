# app/services/keyword_cluster_assignment_service.rb
# Assigns cluster IDs to Keyword records after keyword research
# Uses semantic similarity to group near-duplicate keywords
class KeywordClusterAssignmentService
  # Minimum similarity to consider keywords as cluster siblings
  SIMILARITY_THRESHOLD = 0.85 # High threshold - only cluster very similar keywords
  MAX_CLUSTER_SIZE = 10 # Prevent overly large clusters

  def initialize(keyword_research)
    @keyword_research = keyword_research
    @similarity_service = SemanticSimilarityService.new
  end

  def perform
    keywords = @keyword_research.keywords.to_a
    return if keywords.empty?

    Rails.logger.info "Clustering #{keywords.size} keywords..."

    # Step 1: Build clusters using semantic similarity
    clusters = build_clusters(keywords)

    # Step 2: Assign cluster IDs and mark representatives
    assign_cluster_ids(clusters)

    Rails.logger.info "Clustered into #{clusters.size} groups"
  end

  private

  def build_clusters(keywords)
    return [] if keywords.empty?

    # Get embeddings for all keywords at once (efficient batch processing)
    embeddings_map = {}
    keyword_texts = keywords.map(&:keyword)

    keyword_texts.each_slice(2000) do |batch|
      batch_embeddings = @similarity_service.batch_embed(batch)
      batch.each_with_index do |kw, i|
        embeddings_map[kw] = batch_embeddings[i]
      end
    end

    # Start with each keyword in its own cluster
    # Store keyword objects, not just text
    clusters = keywords.map { |kw_obj| { keywords: [kw_obj], text: kw_obj.keyword } }

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
        # Skip if cluster already at max size
        if clusters[i][:keywords].size >= MAX_CLUSTER_SIZE
          i += 1
          next
        end

        j = i + 1
        while j < clusters.size
          # Check if clusters are similar
          kw1_text = clusters[i][:keywords].first.keyword
          kw2_text = clusters[j][:keywords].first.keyword

          embedding1 = embeddings_map[kw1_text]
          embedding2 = embeddings_map[kw2_text]

          if embedding1 && embedding2
            similarity = @similarity_service.send(:cosine_similarity, embedding1, embedding2)

            if similarity >= SIMILARITY_THRESHOLD
              # Merge cluster j into cluster i
              clusters[i][:keywords].concat(clusters[j][:keywords])
              clusters.delete_at(j)
              merged = true
              next # Check next cluster without incrementing j
            end
          end

          j += 1
        end
        i += 1
      end
    end

    Rails.logger.info "Clustering converged after #{iterations} iterations"

    # Return array of keyword arrays
    clusters.map { |cluster| cluster[:keywords] }
  end

  def assign_cluster_ids(clusters)
    next_cluster_id = (@keyword_research.keywords.maximum(:cluster_id) || 0) + 1

    clusters.each do |cluster_keywords|
      # Only assign cluster if there's more than 1 keyword
      next if cluster_keywords.size < 2

      # Select best representative
      representative = select_representative(cluster_keywords)

      # Assign cluster ID to all keywords in cluster
      cluster_keywords.each do |keyword|
        keyword.update!(
          cluster_id: next_cluster_id,
          is_cluster_representative: (keyword.id == representative.id),
          cluster_size: cluster_keywords.size,
          cluster_keywords: cluster_keywords.reject { |k| k.id == keyword.id }.map(&:keyword)
        )
      end

      Rails.logger.info "  Cluster #{next_cluster_id} (#{cluster_keywords.size}): #{representative.keyword}"
      next_cluster_id += 1
    end
  end

  def select_representative(cluster_keywords)
    # Select best keyword based on:
    # 1. Highest volume × opportunity score
    # 2. Shortest keyword (tiebreaker - more focused)

    cluster_keywords.max_by do |keyword|
      volume = keyword.volume || 0
      opportunity = keyword.opportunity || 0
      length_penalty = -keyword.keyword.length * 0.01 # Slight preference for shorter keywords

      # Score: volume and opportunity are most important
      (volume * opportunity) + length_penalty
    end
  end
end
