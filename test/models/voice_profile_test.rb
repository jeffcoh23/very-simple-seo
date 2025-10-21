require "test_helper"

class VoiceProfileTest < ActiveSupport::TestCase
  # Validations
  test "should validate presence of name" do
    user = create_test_user
    voice = user.voice_profiles.new(description: "Test description")
    assert_not voice.valid?
    assert_includes voice.errors[:name], "can't be blank"
  end

  test "should validate presence of user_id" do
    voice = VoiceProfile.new(name: "Test Voice", description: "Test")
    assert_not voice.valid?
    assert_includes voice.errors[:user], "must exist"
  end

  test "should validate presence of description" do
    user = create_test_user
    voice = user.voice_profiles.new(name: "Test Voice")
    assert_not voice.valid?
    assert_includes voice.errors[:description], "can't be blank"
  end

  test "should automatically unset previous default when setting new default" do
    user = create_test_user

    # Create first default voice
    voice1 = user.voice_profiles.create!(name: "Voice 1", description: "First voice", is_default: true)
    assert voice1.is_default?

    # Create second default voice
    voice2 = user.voice_profiles.create!(name: "Voice 2", description: "Second voice", is_default: true)

    # First voice should no longer be default (callback should have unset it)
    voice1.reload
    assert_not voice1.is_default?
    assert voice2.is_default?
  end

  # Associations
  test "should belong to user" do
    user = create_test_user
    voice = user.voice_profiles.create!(name: "Test Voice", description: "Test description")
    assert_equal user, voice.user
  end

  test "should have many articles" do
    user = create_test_user
    voice = user.voice_profiles.create!(name: "Test Voice", description: "Test description")
    project = user.projects.create!(name: "Test Project", domain: "https://example.com")
    keyword_research = project.keyword_researches.create!(status: :completed)
    keyword = keyword_research.keywords.create!(keyword: "test", volume: 100, difficulty: 50, opportunity: 75)

    article1 = project.articles.create!(keyword: keyword, voice_profile: voice, status: :pending)
    article2 = project.articles.create!(
      keyword: keyword_research.keywords.create!(keyword: "test2", volume: 100, difficulty: 50, opportunity: 75),
      voice_profile: voice,
      status: :pending
    )

    assert_equal 2, voice.articles.count
    assert_includes voice.articles, article1
    assert_includes voice.articles, article2
  end

  test "should nullify articles when voice profile is destroyed" do
    user = create_test_user
    voice = user.voice_profiles.create!(name: "Test Voice", description: "Test description")
    project = user.projects.create!(name: "Test Project", domain: "https://example.com")
    keyword_research = project.keyword_researches.create!(status: :completed)
    keyword = keyword_research.keywords.create!(keyword: "test", volume: 100, difficulty: 50, opportunity: 75)
    article = project.articles.create!(keyword: keyword, voice_profile: voice, status: :pending)

    assert_equal voice, article.voice_profile

    voice.destroy

    article.reload
    assert_nil article.voice_profile
  end

  # Callbacks/Methods
  test "setting voice as default unsets other defaults" do
    user = create_test_user
    voice1 = user.voice_profiles.create!(name: "Voice 1", description: "Desc 1", is_default: true)
    voice2 = user.voice_profiles.create!(name: "Voice 2", description: "Desc 2", is_default: false)
    voice3 = user.voice_profiles.create!(name: "Voice 3", description: "Desc 3", is_default: false)

    # Set voice2 as default
    voice2.update!(is_default: true)

    voice1.reload
    voice3.reload

    assert_not voice1.is_default?
    assert voice2.is_default?
    assert_not voice3.is_default?
  end

  test "can have multiple non-default voices for same user" do
    user = create_test_user
    voice1 = user.voice_profiles.create!(name: "Voice 1", description: "Desc 1", is_default: false)
    voice2 = user.voice_profiles.create!(name: "Voice 2", description: "Desc 2", is_default: false)
    voice3 = user.voice_profiles.create!(name: "Voice 3", description: "Desc 3", is_default: false)

    assert_not voice1.is_default?
    assert_not voice2.is_default?
    assert_not voice3.is_default?
  end

  test "different users can have default voices with same name" do
    user1 = create_test_user
    user2 = create_test_user

    voice1 = user1.voice_profiles.create!(name: "Professional", description: "Prof desc", is_default: true)
    voice2 = user2.voice_profiles.create!(name: "Professional", description: "Prof desc", is_default: true)

    assert voice1.is_default?
    assert voice2.is_default?
    assert_not_equal voice1, voice2
  end
end
