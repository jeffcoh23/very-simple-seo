require "test_helper"

class ArticleTest < ActiveSupport::TestCase
  setup do
    @user = create_test_user
    @project = @user.projects.create!(name: "Test", domain: "https://example.com")
    @research = @project.keyword_researches.create!(status: :completed)
    @keyword = @research.keywords.create!(keyword: "test keyword", volume: 100, difficulty: 50, opportunity: 75)
  end

  # Validations
  test "should validate uniqueness of keyword_id" do
    @project.articles.create!(keyword: @keyword, status: :pending)
    article2 = @project.articles.new(keyword: @keyword, status: :pending)

    assert_not article2.valid?
    assert_includes article2.errors[:keyword_id], "has already been taken"
  end

  # Associations
  test "should belong to keyword" do
    article = @project.articles.create!(keyword: @keyword, status: :pending)
    assert_equal @keyword, article.keyword
  end

  test "should belong to project" do
    article = @project.articles.create!(keyword: @keyword, status: :pending)
    assert_equal @project, article.project
  end

  # Enums
  test "status enum works correctly" do
    article = @project.articles.create!(keyword: @keyword, status: :pending)

    assert article.pending?

    article.update!(status: :generating)
    assert article.generating?

    article.update!(status: :completed)
    assert article.completed?

    article.update!(status: :failed)
    assert article.failed?
  end

  # Export methods
  test "export_markdown returns content" do
    article = @project.articles.create!(
      keyword: @keyword,
      status: :completed,
      content: "# Test Article\n\nThis is test content."
    )

    assert_equal "# Test Article\n\nThis is test content.", article.export_markdown
  end

  test "export_html converts markdown to HTML" do
    article = @project.articles.create!(
      keyword: @keyword,
      status: :completed,
      content: "# Test Article\n\nThis is **bold** text."
    )

    html = article.export_html
    assert_includes html, "<h1"
    assert_includes html, "Test Article"
    assert_includes html, "<strong>bold</strong>"
  end

  # retry! method
  test "retry! resets status and error_message" do
    article = @project.articles.create!(
      keyword: @keyword,
      status: :failed,
      error_message: "Something went wrong"
    )

    # Mock the job to prevent actual execution
    ArticleGenerationJob.expects(:perform_later).with(article.id).once

    article.retry!

    assert article.pending?
    assert_nil article.error_message
  end
end
