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
    assert_equal [k2, k3, k1], ordered.to_a
  end

  test "recommended scope returns keywords with opportunity >= 70" do
    k1 = @research.keywords.create!(keyword: "low", volume: 100, difficulty: 50, opportunity: 50)
    k2 = @research.keywords.create!(keyword: "high", volume: 100, difficulty: 50, opportunity: 75)

    assert_equal [k2], @research.keywords.recommended.to_a
  end

  test "starred scope returns only starred keywords" do
    k1 = @research.keywords.create!(keyword: "starred", volume: 100, difficulty: 50, opportunity: 75, starred: true)
    k2 = @research.keywords.create!(keyword: "not starred", volume: 100, difficulty: 50, opportunity: 75, starred: false)

    assert_equal [k1], @research.keywords.starred.to_a
  end

  test "published scope returns only published keywords" do
    k1 = @research.keywords.create!(keyword: "published", volume: 100, difficulty: 50, opportunity: 75, published: true)
    k2 = @research.keywords.create!(keyword: "not published", volume: 100, difficulty: 50, opportunity: 75, published: false)

    assert_equal [k1], @research.keywords.published.to_a
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
end
