require "test_helper"

class ProjectTest < ActiveSupport::TestCase
  # Validations
  test "should validate presence of name" do
    user = create_test_user
    project = user.projects.new(domain: "https://example.com")
    assert_not project.valid?
    assert_includes project.errors[:name], "can't be blank"
  end

  test "should validate presence of domain" do
    user = create_test_user
    project = user.projects.new(name: "Test Project")
    assert_not project.valid?
    assert_includes project.errors[:domain], "can't be blank"
  end

  test "should validate domain format" do
    user = create_test_user
    project = user.projects.new(name: "Test", domain: "invalid-domain")
    assert_not project.valid?
    assert_includes project.errors[:domain], "is invalid"
  end

  test "should accept valid http URL" do
    user = create_test_user
    project = user.projects.new(name: "Test", domain: "http://example.com")
    assert project.valid?
  end

  test "should accept valid https URL" do
    user = create_test_user
    project = user.projects.new(name: "Test", domain: "https://example.com")
    assert project.valid?
  end

  # Associations
  test "should belong to user" do
    user = create_test_user
    project = user.projects.create!(name: "Test", domain: "https://example.com")
    assert_equal user, project.user
  end

  test "should have many competitors" do
    user = create_test_user
    project = user.projects.create!(name: "Test", domain: "https://example.com")

    competitor1 = project.competitors.create!(domain: "https://competitor1.com")
    competitor2 = project.competitors.create!(domain: "https://competitor2.com")

    assert_equal 2, project.competitors.count
    assert_includes project.competitors, competitor1
    assert_includes project.competitors, competitor2
  end

  test "should have many keyword_researches" do
    user = create_test_user
    project = user.projects.create!(name: "Test", domain: "https://example.com")

    research1 = project.keyword_researches.create!(status: :pending)
    research2 = project.keyword_researches.create!(status: :completed)

    assert_equal 2, project.keyword_researches.count
  end

  test "should have many keywords through keyword_researches" do
    user = create_test_user
    project = user.projects.create!(name: "Test", domain: "https://example.com")
    research = project.keyword_researches.create!(status: :completed)

    keyword1 = research.keywords.create!(keyword: "test keyword 1", volume: 100, difficulty: 50, opportunity: 75)
    keyword2 = research.keywords.create!(keyword: "test keyword 2", volume: 200, difficulty: 40, opportunity: 80)

    assert_equal 2, project.keywords.count
    assert_includes project.keywords, keyword1
    assert_includes project.keywords, keyword2
  end

  test "should have many articles" do
    user = create_test_user
    project = user.projects.create!(name: "Test", domain: "https://example.com")
    research = project.keyword_researches.create!(status: :completed)
    keyword = research.keywords.create!(keyword: "test", volume: 100, difficulty: 50, opportunity: 75)

    article = project.articles.create!(keyword: keyword, status: :pending)

    assert_equal 1, project.articles.count
    assert_includes project.articles, article
  end

  # Cascade deletes
  test "should destroy associated competitors when project is destroyed" do
    user = create_test_user
    project = user.projects.create!(name: "Test", domain: "https://example.com")
    project.competitors.create!(domain: "https://competitor.com")

    assert_difference "Competitor.count", -1 do
      project.destroy
    end
  end

  test "should destroy associated keyword_researches when project is destroyed" do
    user = create_test_user
    project = user.projects.create!(name: "Test", domain: "https://example.com")
    project.keyword_researches.create!(status: :pending)

    assert_difference "KeywordResearch.count", -1 do
      project.destroy
    end
  end

  test "should destroy associated articles when project is destroyed" do
    user = create_test_user
    project = user.projects.create!(name: "Test", domain: "https://example.com")
    research = project.keyword_researches.create!(status: :completed)
    keyword = research.keywords.create!(keyword: "test", volume: 100, difficulty: 50, opportunity: 75)
    project.articles.create!(keyword: keyword, status: :pending)

    assert_difference "Article.count", -1 do
      project.destroy
    end
  end

  # Helper methods
  test "default_cta returns first CTA" do
    user = create_test_user
    project = user.projects.create!(
      name: "Test",
      domain: "https://example.com",
      call_to_actions: [
        { text: "First CTA", url: "https://example.com/cta1" },
        { text: "Second CTA", url: "https://example.com/cta2" }
      ]
    )

    assert_equal({ "text" => "First CTA", "url" => "https://example.com/cta1" }, project.default_cta)
  end

  test "default_cta returns nil when no CTAs" do
    user = create_test_user
    project = user.projects.create!(name: "Test", domain: "https://example.com")

    assert_nil project.default_cta
  end
end
