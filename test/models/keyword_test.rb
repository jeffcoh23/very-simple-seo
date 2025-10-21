require "test_helper"

class KeywordTest < ActiveSupport::TestCase
  setup do
    @user = create_test_user
    @project = @user.projects.create!(name: "Test", domain: "https://example.com")
    @research = @project.keyword_researches.create!(status: :completed)
  end

  # Validations
  test "should validate presence of keyword" do
    keyword = @research.keywords.new(volume: 100, difficulty: 50, opportunity: 75)
    assert_not keyword.valid?
    assert_includes keyword.errors[:keyword], "can't be blank"
  end

  # Associations
  test "should belong to keyword_research" do
    keyword = @research.keywords.create!(keyword: "test", volume: 100, difficulty: 50, opportunity: 75)
    assert_equal @research, keyword.keyword_research
  end

  test "should have one article" do
    keyword = @research.keywords.create!(keyword: "test", volume: 100, difficulty: 50, opportunity: 75)
    article = keyword.build_article(project: @project, status: :pending)
    article.save!

    assert_equal article, keyword.article
  end

  test "should have project through keyword_research" do
    keyword = @research.keywords.create!(keyword: "test", volume: 100, difficulty: 50, opportunity: 75)
    assert_equal @project, keyword.project
  end

  # Scopes
  test "by_opportunity scope orders by opportunity desc" do
    k1 = @research.keywords.create!(keyword: "low", volume: 100, difficulty: 50, opportunity: 50)
    k2 = @research.keywords.create!(keyword: "high", volume: 100, difficulty: 50, opportunity: 90)
    k3 = @research.keywords.create!(keyword: "medium", volume: 100, difficulty: 50, opportunity: 70)

    ordered = @research.keywords.by_opportunity
    assert_equal [ k2, k3, k1 ], ordered.to_a
  end

  test "recommended scope returns keywords with opportunity >= 70" do
    k1 = @research.keywords.create!(keyword: "low", volume: 100, difficulty: 50, opportunity: 50)
    k2 = @research.keywords.create!(keyword: "high", volume: 100, difficulty: 50, opportunity: 75)

    assert_equal [ k2 ], @research.keywords.recommended.to_a
  end

  test "starred scope returns only starred keywords" do
    k1 = @research.keywords.create!(keyword: "starred", volume: 100, difficulty: 50, opportunity: 75, starred: true)
    k2 = @research.keywords.create!(keyword: "not starred", volume: 100, difficulty: 50, opportunity: 75, starred: false)

    assert_equal [ k1 ], @research.keywords.starred.to_a
  end

  test "published scope returns only published keywords" do
    k1 = @research.keywords.create!(keyword: "published", volume: 100, difficulty: 50, opportunity: 75, published: true)
    k2 = @research.keywords.create!(keyword: "not published", volume: 100, difficulty: 50, opportunity: 75, published: false)

    assert_equal [ k1 ], @research.keywords.published.to_a
  end

  # Helper methods
  test "easy_win? returns true when opportunity >= 70" do
    keyword = @research.keywords.create!(keyword: "test", volume: 100, difficulty: 50, opportunity: 75)
    assert keyword.easy_win?
  end

  test "easy_win? returns false when opportunity < 70" do
    keyword = @research.keywords.create!(keyword: "test", volume: 100, difficulty: 50, opportunity: 65)
    assert_not keyword.easy_win?
  end

  test "medium_opportunity? returns true when 50 <= opportunity < 70" do
    keyword = @research.keywords.create!(keyword: "test", volume: 100, difficulty: 50, opportunity: 60)
    assert keyword.medium_opportunity?
  end

  test "medium_opportunity? returns false when opportunity < 50" do
    keyword = @research.keywords.create!(keyword: "test", volume: 100, difficulty: 50, opportunity: 40)
    assert_not keyword.medium_opportunity?
  end

  test "difficulty_level returns Low when difficulty < 33" do
    keyword = @research.keywords.create!(keyword: "test", volume: 100, difficulty: 20, opportunity: 75)
    assert_equal "Low", keyword.difficulty_level
  end

  test "difficulty_level returns Medium when 33 <= difficulty < 66" do
    keyword = @research.keywords.create!(keyword: "test", volume: 100, difficulty: 50, opportunity: 75)
    assert_equal "Medium", keyword.difficulty_level
  end

  test "difficulty_level returns High when difficulty >= 66" do
    keyword = @research.keywords.create!(keyword: "test", volume: 100, difficulty: 80, opportunity: 75)
    assert_equal "High", keyword.difficulty_level
  end

  test "difficulty_badge_color returns green emoji for easy" do
    keyword = @research.keywords.create!(keyword: "test", volume: 100, difficulty: 20, opportunity: 75)
    assert_equal "🟢", keyword.difficulty_badge_color
  end

  test "difficulty_badge_color returns yellow emoji for medium" do
    keyword = @research.keywords.create!(keyword: "test", volume: 100, difficulty: 50, opportunity: 75)
    assert_equal "🟡", keyword.difficulty_badge_color
  end

  test "difficulty_badge_color returns red emoji for hard" do
    keyword = @research.keywords.create!(keyword: "test", volume: 100, difficulty: 80, opportunity: 75)
    assert_equal "🔴", keyword.difficulty_badge_color
  end

  # Enums
  test "generation_status enum works correctly" do
    keyword = @research.keywords.create!(keyword: "test", volume: 100, difficulty: 50, opportunity: 75)

    assert keyword.not_started?

    keyword.update!(generation_status: :queued)
    assert keyword.queued?

    keyword.update!(generation_status: :generating)
    assert keyword.generating?

    keyword.update!(generation_status: :completed)
    assert keyword.completed?

    keyword.update!(generation_status: :failed)
    assert keyword.failed?
  end

  # Clustering - Scopes
  test "cluster_representatives scope returns only cluster representatives" do
    rep = @research.keywords.create!(keyword: "seo tools", volume: 1000, difficulty: 50, opportunity: 75, cluster_id: 1, is_cluster_representative: true)
    member = @research.keywords.create!(keyword: "tools for seo", volume: 100, difficulty: 50, opportunity: 75, cluster_id: 1, is_cluster_representative: false)
    unclustered = @research.keywords.create!(keyword: "other keyword", volume: 100, difficulty: 50, opportunity: 75)

    assert_equal [ rep ], @research.keywords.cluster_representatives.to_a
  end

  test "in_cluster scope returns keywords in specific cluster" do
    k1 = @research.keywords.create!(keyword: "seo tools", volume: 1000, difficulty: 50, opportunity: 75, cluster_id: 1, is_cluster_representative: true)
    k2 = @research.keywords.create!(keyword: "tools for seo", volume: 100, difficulty: 50, opportunity: 75, cluster_id: 1, is_cluster_representative: false)
    k3 = @research.keywords.create!(keyword: "other keyword", volume: 100, difficulty: 50, opportunity: 75, cluster_id: 2, is_cluster_representative: true)

    assert_equal [ k1, k2 ], @research.keywords.in_cluster(1).order(:id).to_a
  end

  test "unclustered scope returns keywords without cluster_id" do
    clustered = @research.keywords.create!(keyword: "seo tools", volume: 1000, difficulty: 50, opportunity: 75, cluster_id: 1, is_cluster_representative: true)
    unclustered = @research.keywords.create!(keyword: "other keyword", volume: 100, difficulty: 50, opportunity: 75)

    assert_equal [ unclustered ], @research.keywords.unclustered.to_a
  end

  # Clustering - Helper methods
  test "clustered? returns true when cluster_id is present" do
    keyword = @research.keywords.create!(keyword: "seo tools", volume: 1000, difficulty: 50, opportunity: 75, cluster_id: 1)
    assert keyword.clustered?
  end

  test "clustered? returns false when cluster_id is nil" do
    keyword = @research.keywords.create!(keyword: "other keyword", volume: 100, difficulty: 50, opportunity: 75)
    assert_not keyword.clustered?
  end

  test "cluster_siblings returns other keywords in same cluster" do
    rep = @research.keywords.create!(keyword: "seo tools", volume: 1000, difficulty: 50, opportunity: 75, cluster_id: 1, is_cluster_representative: true)
    sibling1 = @research.keywords.create!(keyword: "tools for seo", volume: 100, difficulty: 50, opportunity: 75, cluster_id: 1)
    sibling2 = @research.keywords.create!(keyword: "seo tool", volume: 50, difficulty: 50, opportunity: 75, cluster_id: 1)
    other_cluster = @research.keywords.create!(keyword: "other", volume: 100, difficulty: 50, opportunity: 75, cluster_id: 2)

    siblings = rep.cluster_siblings.order(:id).to_a
    assert_equal 2, siblings.length
    assert_includes siblings, sibling1
    assert_includes siblings, sibling2
    assert_not_includes siblings, rep
    assert_not_includes siblings, other_cluster
  end

  test "cluster_siblings returns empty relation for unclustered keyword" do
    keyword = @research.keywords.create!(keyword: "unclustered", volume: 100, difficulty: 50, opportunity: 75)
    assert_equal [], keyword.cluster_siblings.to_a
  end

  test "cluster_representative returns the cluster representative" do
    rep = @research.keywords.create!(keyword: "seo tools", volume: 1000, difficulty: 50, opportunity: 75, cluster_id: 1, is_cluster_representative: true)
    member = @research.keywords.create!(keyword: "tools for seo", volume: 100, difficulty: 50, opportunity: 75, cluster_id: 1)

    assert_equal rep, member.cluster_representative
  end

  test "cluster_representative returns nil for unclustered keyword" do
    keyword = @research.keywords.create!(keyword: "unclustered", volume: 100, difficulty: 50, opportunity: 75)
    assert_nil keyword.cluster_representative
  end

  test "cluster_members returns all keywords in cluster including self" do
    rep = @research.keywords.create!(keyword: "seo tools", volume: 1000, difficulty: 50, opportunity: 75, cluster_id: 1, is_cluster_representative: true)
    member1 = @research.keywords.create!(keyword: "tools for seo", volume: 100, difficulty: 50, opportunity: 75, cluster_id: 1)
    member2 = @research.keywords.create!(keyword: "seo tool", volume: 50, difficulty: 50, opportunity: 75, cluster_id: 1)

    members = rep.cluster_members.order(:id).to_a
    assert_equal 3, members.length
    assert_includes members, rep
    assert_includes members, member1
    assert_includes members, member2
  end
end
