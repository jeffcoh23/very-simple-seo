require "test_helper"

class KeywordClusterAssignmentServiceTest < ActiveSupport::TestCase
  setup do
    @user = create_test_user
    @project = @user.projects.create!(name: "Test Project", domain: "https://example.com")
    @research = @project.keyword_researches.create!(status: :completed)
  end

  test "skips clustering when no keywords exist" do
    service = KeywordClusterAssignmentService.new(@research)

    assert_nothing_raised do
      service.perform
    end

    assert_equal 0, @research.keywords.cluster_representatives.count
  end

  test "does not cluster single keyword" do
    @research.keywords.create!(keyword: "seo tools", volume: 1000, difficulty: 50, opportunity: 75)

    service = KeywordClusterAssignmentService.new(@research)
    service.perform

    assert_equal 0, @research.keywords.cluster_representatives.count
    assert_equal 1, @research.keywords.unclustered.count
  end

  test "clusters similar keywords with similarity >= 0.85" do
    k1 = @research.keywords.create!(keyword: "seo tools", volume: 1000, difficulty: 50, opportunity: 75)
    k2 = @research.keywords.create!(keyword: "tools for seo", volume: 500, difficulty: 50, opportunity: 70)
    k3 = @research.keywords.create!(keyword: "seo tool", volume: 300, difficulty: 50, opportunity: 65)

    # Mock the similarity service to return high similarity
    SemanticSimilarityService.stub :calculate_similarity, 0.90 do
      service = KeywordClusterAssignmentService.new(@research)
      service.perform
    end

    k1.reload
    k2.reload
    k3.reload

    # All should be in same cluster
    assert_equal k1.cluster_id, k2.cluster_id
    assert_equal k1.cluster_id, k3.cluster_id

    # k1 should be representative (highest volume)
    assert k1.is_cluster_representative
    assert_not k2.is_cluster_representative
    assert_not k3.is_cluster_representative

    # Cluster size should be set
    assert_equal 3, k1.cluster_size

    # Cluster keywords should be stored
    assert_equal [ "tools for seo", "seo tool" ].sort, k1.cluster_keywords.sort
  end

  test "does not cluster keywords with similarity < 0.85" do
    k1 = @research.keywords.create!(keyword: "seo tools", volume: 1000, difficulty: 50, opportunity: 75)
    k2 = @research.keywords.create!(keyword: "content marketing", volume: 500, difficulty: 50, opportunity: 70)

    # Mock the similarity service to return low similarity
    SemanticSimilarityService.stub :calculate_similarity, 0.50 do
      service = KeywordClusterAssignmentService.new(@research)
      service.perform
    end

    k1.reload
    k2.reload

    # Keywords should not be clustered
    assert_nil k1.cluster_id
    assert_nil k2.cluster_id
    assert_equal 2, @research.keywords.unclustered.count
  end

  test "selects representative with highest volume * opportunity score" do
    k1 = @research.keywords.create!(keyword: "seo tools online", volume: 500, difficulty: 50, opportunity: 75) # 37500
    k2 = @research.keywords.create!(keyword: "seo tools", volume: 1000, difficulty: 50, opportunity: 80) # 80000 (best)
    k3 = @research.keywords.create!(keyword: "tools for seo", volume: 800, difficulty: 50, opportunity: 70) # 56000

    SemanticSimilarityService.stub :calculate_similarity, 0.90 do
      service = KeywordClusterAssignmentService.new(@research)
      service.perform
    end

    k2.reload

    # k2 should be representative (highest volume * opportunity)
    assert k2.is_cluster_representative
    assert_equal 3, k2.cluster_size
  end

  test "prefers shorter keywords when scores are equal" do
    k1 = @research.keywords.create!(keyword: "seo tools for professionals", volume: 1000, difficulty: 50, opportunity: 75) # Longer
    k2 = @research.keywords.create!(keyword: "seo tools", volume: 1000, difficulty: 50, opportunity: 75) # Shorter (best)

    SemanticSimilarityService.stub :calculate_similarity, 0.90 do
      service = KeywordClusterAssignmentService.new(@research)
      service.perform
    end

    k2.reload

    # k2 should be representative (shorter keyword)
    assert k2.is_cluster_representative
  end

  test "limits cluster size to max 10 keywords" do
    # Create 12 very similar keywords
    keywords = 12.times.map do |i|
      @research.keywords.create!(keyword: "seo tool #{i}", volume: 100 - i, difficulty: 50, opportunity: 75)
    end

    SemanticSimilarityService.stub :calculate_similarity, 0.95 do
      service = KeywordClusterAssignmentService.new(@research)
      service.perform
    end

    representative = @research.keywords.cluster_representatives.first
    assert_not_nil representative

    # Cluster size should be limited to 10
    assert representative.cluster_size <= 10
  end

  test "creates multiple clusters for different keyword groups" do
    # Group 1: SEO tools
    seo1 = @research.keywords.create!(keyword: "seo tools", volume: 1000, difficulty: 50, opportunity: 75)
    seo2 = @research.keywords.create!(keyword: "tools for seo", volume: 500, difficulty: 50, opportunity: 70)

    # Group 2: Content marketing
    content1 = @research.keywords.create!(keyword: "content marketing", volume: 800, difficulty: 50, opportunity: 75)
    content2 = @research.keywords.create!(keyword: "marketing content", volume: 400, difficulty: 50, opportunity: 70)

    # Mock to return high similarity within groups, low between groups
    SemanticSimilarityService.stub :calculate_similarity, lambda { |text1, text2|
      if (text1.include?("seo") && text2.include?("seo")) ||
         (text1.include?("content") && text2.include?("content"))
        0.90
      else
        0.30
      end
    } do
      service = KeywordClusterAssignmentService.new(@research)
      service.perform
    end

    seo1.reload
    content1.reload

    # Should have 2 cluster representatives
    assert_equal 2, @research.keywords.cluster_representatives.count

    # Clusters should be different
    assert_not_nil seo1.cluster_id
    assert_not_nil content1.cluster_id
    assert_not_equal seo1.cluster_id, content1.cluster_id
  end

  test "handles keywords with nil or empty text" do
    k1 = @research.keywords.create!(keyword: "seo tools", volume: 1000, difficulty: 50, opportunity: 75)
    k2 = @research.keywords.create!(keyword: "", volume: 500, difficulty: 50, opportunity: 70)

    service = KeywordClusterAssignmentService.new(@research)

    assert_nothing_raised do
      service.perform
    end

    k1.reload
    assert_nil k1.cluster_id # Should not cluster with invalid keyword
  end

  test "stores cluster keywords as array of strings" do
    k1 = @research.keywords.create!(keyword: "seo tools", volume: 1000, difficulty: 50, opportunity: 75)
    k2 = @research.keywords.create!(keyword: "tools for seo", volume: 500, difficulty: 50, opportunity: 70)
    k3 = @research.keywords.create!(keyword: "seo tool", volume: 300, difficulty: 50, opportunity: 65)

    SemanticSimilarityService.stub :calculate_similarity, 0.90 do
      service = KeywordClusterAssignmentService.new(@research)
      service.perform
    end

    representative = @research.keywords.cluster_representatives.first
    assert_not_nil representative
    assert_instance_of Array, representative.cluster_keywords
    assert_equal 2, representative.cluster_keywords.length
    assert representative.cluster_keywords.all? { |k| k.is_a?(String) }
  end

  test "assigns unique cluster IDs" do
    # Create 3 groups of similar keywords
    group1 = 2.times.map { |i| @research.keywords.create!(keyword: "seo #{i}", volume: 100, difficulty: 50, opportunity: 75) }
    group2 = 2.times.map { |i| @research.keywords.create!(keyword: "content #{i}", volume: 100, difficulty: 50, opportunity: 75) }
    group3 = 2.times.map { |i| @research.keywords.create!(keyword: "marketing #{i}", volume: 100, difficulty: 50, opportunity: 75) }

    SemanticSimilarityService.stub :calculate_similarity, lambda { |text1, text2|
      # High similarity within same word group
      words1 = text1.split
      words2 = text2.split
      (words1 & words2).any? ? 0.90 : 0.30
    } do
      service = KeywordClusterAssignmentService.new(@research)
      service.perform
    end

    cluster_ids = @research.keywords.cluster_representatives.pluck(:cluster_id)

    # Should have 3 unique cluster IDs
    assert_equal 3, cluster_ids.uniq.length
  end

  test "performance - handles large number of keywords efficiently" do
    # Create 50 keywords
    50.times do |i|
      @research.keywords.create!(keyword: "keyword #{i}", volume: 100 - i, difficulty: 50, opportunity: 75)
    end

    SemanticSimilarityService.stub :calculate_similarity, 0.30 do # All different
      start_time = Time.now

      service = KeywordClusterAssignmentService.new(@research)
      service.perform

      elapsed = Time.now - start_time

      # Should complete in reasonable time (< 5 seconds for 50 keywords)
      assert elapsed < 5, "Clustering took #{elapsed}s, expected < 5s"
    end
  end
end
