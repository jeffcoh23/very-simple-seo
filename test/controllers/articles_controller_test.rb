require "test_helper"

class ArticlesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create_test_user
    sign_in(@user)

    @project = @user.projects.create!(name: "Test Project", domain: "https://example.com")
    @research = @project.keyword_researches.create!(status: :completed)
    @keyword = @research.keywords.create!(keyword: "test keyword", volume: 100, difficulty: 50, opportunity: 75)

    # Destroy default voice profiles to avoid conflicts
    @user.voice_profiles.destroy_all

    @voice1 = @user.voice_profiles.create!(name: "Professional", description: "Professional tone", is_default: true)
    @voice2 = @user.voice_profiles.create!(name: "Casual", description: "Casual tone", is_default: false)
  end

  def sign_in(user)
    post "/sign_in", params: {
      email_address: user.email_address,
      password: "password123"
    }
  end

  # GET /keywords/:id/generate (new action)
  test "should get new article generation page" do
    get "/keywords/#{@keyword.id}/generate"
    assert_response :success
  end

  test "should redirect if article already exists for keyword" do
    @project.articles.create!(keyword: @keyword, status: :pending)

    get "/keywords/#{@keyword.id}/generate"
    assert_redirected_to "/articles/#{@keyword.article.id}"
  end

  test "should not allow accessing other user's keywords" do
    other_user = create_test_user
    other_project = other_user.projects.create!(name: "Other Project", domain: "https://other.com")
    other_research = other_project.keyword_researches.create!(status: :completed)
    other_keyword = other_research.keywords.create!(keyword: "other keyword", volume: 100, difficulty: 50, opportunity: 75)

    get "/keywords/#{other_keyword.id}/generate"
    assert_redirected_to "/projects"
  end

  # POST /projects/:project_id/articles (create action)
  test "should create article with selected voice_profile_id" do
    # Give user credits
    @user.update!(credits: 5)

    # Mock the job to prevent actual execution
    ArticleGenerationJob.expects(:perform_later).once

    assert_difference "Article.count", 1 do
      post "/projects/#{@project.id}/articles", params: {
        keyword_id: @keyword.id,
        target_word_count: 2000,
        voice_profile_id: @voice2.id
      }
    end

    article = Article.last
    assert_equal @voice2, article.voice_profile
    assert_equal @keyword, article.keyword
    assert_equal 2000, article.target_word_count
  end

  test "should default to user's default voice if no voice_profile_id provided" do
    @user.update!(credits: 5)
    ArticleGenerationJob.expects(:perform_later).once

    assert_difference "Article.count", 1 do
      post "/projects/#{@project.id}/articles", params: {
        keyword_id: @keyword.id,
        target_word_count: 2000
      }
    end

    article = Article.last
    assert_equal @voice1, article.voice_profile  # voice1 is marked as default
  end

  test "should allow creating article without voice_profile" do
    @user.update!(credits: 5)
    # Remove all voice profiles
    @user.voice_profiles.destroy_all

    ArticleGenerationJob.expects(:perform_later).once

    assert_difference "Article.count", 1 do
      post "/projects/#{@project.id}/articles", params: {
        keyword_id: @keyword.id,
        target_word_count: 2000
      }
    end

    article = Article.last
    assert_nil article.voice_profile
  end

  test "should deduct credit when creating article" do
    @user.update!(credits: 3)
    ArticleGenerationJob.expects(:perform_later).once

    assert_difference "@user.reload.credits", -1 do
      post "/projects/#{@project.id}/articles", params: {
        keyword_id: @keyword.id,
        target_word_count: 2000
      }
    end
  end

  test "should not create article without credits" do
    @user.update!(credits: 0)

    assert_no_difference "Article.count" do
      post "/projects/#{@project.id}/articles", params: {
        keyword_id: @keyword.id,
        target_word_count: 2000
      }
    end

    assert_redirected_to "/pricing"
  end

  test "should not create duplicate article for same keyword" do
    @user.update!(credits: 5)
    @project.articles.create!(keyword: @keyword, status: :pending)

    assert_no_difference "Article.count" do
      post "/projects/#{@project.id}/articles", params: {
        keyword_id: @keyword.id,
        target_word_count: 2000
      }
    end
  end

  # Show, Destroy, Export tests (basic coverage)
  test "should show article" do
    article = @project.articles.create!(keyword: @keyword, status: :completed, title: "Test Article", content: "Content")

    get "/articles/#{article.id}"
    assert_response :success
  end

  test "should not show other user's article" do
    other_user = create_test_user
    other_project = other_user.projects.create!(name: "Other", domain: "https://other.com")
    other_research = other_project.keyword_researches.create!(status: :completed)
    other_keyword = other_research.keywords.create!(keyword: "other", volume: 100, difficulty: 50, opportunity: 75)
    other_article = other_project.articles.create!(keyword: other_keyword, status: :completed)

    get "/articles/#{other_article.id}"
    assert_redirected_to "/projects"
  end

  test "should destroy article" do
    article = @project.articles.create!(keyword: @keyword, status: :pending)

    assert_difference "Article.count", -1 do
      delete "/articles/#{article.id}"
    end

    assert_redirected_to "/projects/#{@project.id}"
  end

  test "should not destroy other user's article" do
    other_user = create_test_user
    other_project = other_user.projects.create!(name: "Other", domain: "https://other.com")
    other_research = other_project.keyword_researches.create!(status: :completed)
    other_keyword = other_research.keywords.create!(keyword: "other", volume: 100, difficulty: 50, opportunity: 75)
    other_article = other_project.articles.create!(keyword: other_keyword, status: :pending)

    assert_no_difference "Article.count" do
      delete "/articles/#{other_article.id}"
    end

    assert_redirected_to "/projects"
  end
end
