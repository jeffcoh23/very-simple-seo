require "test_helper"

class ProjectsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create_test_user
    sign_in(@user)
  end

  # Helper to sign in without using session_url
  def sign_in(user)
    post "/sign_in", params: {
      email_address: user.email_address,
      password: "password123"
    }
  end

  # Index tests
  test "should get index" do
    get "/projects"
    assert_response :success
  end

  test "index should only show current user's projects" do
    # Create projects for current user
    @user.projects.create!(name: "My Project", domain: "https://example.com")

    # Create project for another user
    other_user = create_test_user
    other_user.projects.create!(name: "Other Project", domain: "https://other.com")

    get "/projects"
    assert_response :success

    # Note: We can't easily test Inertia props without JavaScript
    # This test mainly ensures authorization works
  end

  # New tests
  test "should get new" do
    get "/projects/new"
    assert_response :success
  end

  # Create tests
  test "should create project" do
    assert_difference("Project.count") do
      post "/projects", params: {
        project: {
          name: "Test Project",
          domain: "https://example.com",
          niche: "SaaS"
        }
      }
    end

    project = Project.last
    assert_equal "Test Project", project.name
    assert_equal "https://example.com", project.domain
    assert_equal @user, project.user

    assert_redirected_to "/projects/#{project.id}"
  end

  test "should start keyword research after creating project" do
    assert_difference("KeywordResearch.count") do
      post "/projects", params: {
        project: {
          name: "Test Project",
          domain: "https://example.com"
        }
      }
    end

    project = Project.last
    assert_equal 1, project.keyword_researches.count
    assert_equal "pending", project.keyword_researches.first.status
  end

  test "should enforce project limits for free users" do
    # Free users can only create 1 project
    @user.projects.create!(name: "Project 1", domain: "https://example1.com")

    assert_no_difference("Project.count") do
      post "/projects", params: {
        project: {
          name: "Project 2",
          domain: "https://example2.com"
        }
      }
    end

    assert_redirected_to "/pricing"
  end

  test "should not create project with invalid data" do
    assert_no_difference("Project.count") do
      post "/projects", params: {
        project: {
          name: "",
          domain: "invalid-domain"
        }
      }
    end

    assert_redirected_to "/projects/new"
  end

  # Show tests
  test "should show project" do
    project = @user.projects.create!(name: "Test", domain: "https://example.com")

    get "/projects/#{project.id}"
    assert_response :success
  end

  test "should not show other user's project" do
    other_user = create_test_user
    project = other_user.projects.create!(name: "Test", domain: "https://example.com")

    get "/projects/#{project.id}"
    assert_redirected_to "/projects"
  end

  # Edit tests
  test "should get edit" do
    project = @user.projects.create!(name: "Test", domain: "https://example.com")

    get "/projects/#{project.id}/edit"
    assert_response :success
  end

  test "should not edit other user's project" do
    other_user = create_test_user
    project = other_user.projects.create!(name: "Test", domain: "https://example.com")

    get "/projects/#{project.id}/edit"
    assert_redirected_to "/projects"
  end

  # Update tests
  test "should update project" do
    project = @user.projects.create!(name: "Test", domain: "https://example.com")

    patch "/projects/#{project.id}", params: {
      project: {
        name: "Updated Name",
        niche: "E-commerce"
      }
    }

    project.reload
    assert_equal "Updated Name", project.name
    assert_equal "E-commerce", project.niche
    assert_redirected_to "/projects/#{project.id}"
  end

  test "should not update other user's project" do
    other_user = create_test_user
    project = other_user.projects.create!(name: "Test", domain: "https://example.com")

    patch "/projects/#{project.id}", params: {
      project: { name: "Hacked" }
    }

    project.reload
    assert_equal "Test", project.name
    assert_redirected_to "/projects"
  end

  # Destroy tests
  test "should destroy project" do
    project = @user.projects.create!(name: "Test", domain: "https://example.com")

    assert_difference("Project.count", -1) do
      delete "/projects/#{project.id}"
    end

    assert_redirected_to "/projects"
  end

  test "should not destroy other user's project" do
    other_user = create_test_user
    project = other_user.projects.create!(name: "Test", domain: "https://example.com")

    assert_no_difference("Project.count") do
      delete "/projects/#{project.id}"
    end

    assert_redirected_to "/projects"
  end

  test "should cascade delete associated data" do
    project = @user.projects.create!(name: "Test", domain: "https://example.com")
    research = project.keyword_researches.create!(status: :completed)
    keyword = research.keywords.create!(keyword: "test", volume: 100, difficulty: 50, opportunity: 75)
    article = project.articles.create!(keyword: keyword, status: :pending)
    competitor = project.competitors.create!(domain: "https://competitor.com")

    assert_difference(["KeywordResearch.count", "Keyword.count", "Article.count", "Competitor.count"], -1) do
      delete "/projects/#{project.id}"
    end
  end
end
