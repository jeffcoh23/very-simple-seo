# VerySimpleSEO - Technical Document

## Overview

VerySimpleSEO is a Rails 8 SaaS application that helps solopreneurs and indie hackers perform keyword research and generate SEO-optimized articles. It will be built from scratch using our Rails 8 SaaS template, then extended with SEO-specific features adapted from the existing `bin/keyword_research` and `bin/generate_article` scripts.

---

## Technology Stack

### Starting Point: Rails 8 SaaS Template
We'll use `docs/template-enhanced.rb` which provides:
- **Framework:** Rails 8.0+ with PostgreSQL 16+
- **Authentication:** Rails 8 auth with first_name, last_name, email verification
- **Frontend:** Inertia.js + React + Vite + shadcn/ui + Tailwind v4
- **Background Jobs:** Solid Queue (Rails 8 default)
- **Payments:** Stripe via Pay gem with lookup_key plans
- **Email:** Resend (production) + letter_opener_web (development)
- **SEO:** OG/Twitter meta tags + sitemap generator
- **Deployment:** Fly.io ready

### Additional Dependencies for VerySimpleSEO
- **AI Models:**
  - OpenAI GPT-4o Mini (`gpt-4o-mini`) - Article writing, high-quality content
  - Google Gemini 2.5 Flash (`gemini-2.5-flash`) - Analysis, outline generation, SERP research
- **Search API:** Google Custom Search JSON API
- **Web Scraping:** Nokogiri (already in Rails) + Net::HTTP

### New Gems to Add
```ruby
# Gemfile additions beyond template
gem 'nokogiri' # Already included in Rails
gem 'ruby_llm' # Unified LLM wrapper (OpenAI, Gemini, Anthropic, etc.)
```

---

## Application Structure

### Base Template Provides
```
app/
├── controllers/
│   ├── application_controller.rb      # Inertia + auth setup
│   ├── sessions_controller.rb         # Login
│   ├── registrations_controller.rb    # Signup with plan selection
│   ├── billing_controller.rb          # Stripe checkout + portal
│   ├── webhooks_controller.rb         # Stripe webhooks (Pay)
│   ├── dashboard_controller.rb        # Authenticated dashboard
│   └── settings_controller.rb         # User settings
├── models/
│   └── user.rb                        # pay_customer, email_verified?, plan helpers
├── services/
│   └── plans_service.rb               # Centralized plan configuration
├── jobs/
│   └── (Solid Queue setup)
├── mailers/
│   └── email_verification_mailer.rb   # Email verification
└── frontend/
    ├── components/
    │   ├── ui/                        # shadcn/ui components
    │   └── marketing/                 # Public-facing components
    ├── pages/
    │   ├── Auth/                      # Login, Signup
    │   ├── App/                       # Dashboard, Settings
    │   ├── Home.jsx                   # Marketing homepage
    │   └── Pricing.jsx                # Pricing page
    └── layout/
        └── AppLayout.jsx              # Authenticated app shell
```

### VerySimpleSEO Extensions
```
app/
├── controllers/
│   ├── projects_controller.rb         # NEW: CRUD for projects
│   ├── keyword_researches_controller.rb # NEW: Trigger research
│   ├── keywords_controller.rb         # NEW: View keyword opportunities
│   └── articles_controller.rb         # NEW: Generate + view articles
├── models/
│   ├── project.rb                     # NEW
│   ├── competitor.rb                  # NEW
│   ├── keyword_research.rb            # NEW
│   ├── keyword.rb                     # NEW
│   └── article.rb                     # NEW
├── services/
│   ├── ai/
│   │   └── client_service.rb          # NEW: Unified AI client (ruby_llm)
│   ├── keyword_research_service.rb    # NEW: Adapted from bin/keyword_research
│   ├── article_generation_service.rb  # NEW: Adapted from bin/generate_article
│   ├── serp_research_service.rb       # NEW
│   ├── google_suggestions_service.rb  # NEW
│   ├── reddit_miner_service.rb        # NEW
│   ├── competitor_analysis_service.rb # NEW
│   └── voice_analysis_service.rb      # NEW (optional)
├── jobs/
│   ├── keyword_research_job.rb        # NEW
│   └── article_generation_job.rb      # NEW
└── frontend/
    ├── components/
    │   └── app/
    │       ├── ProjectCard.jsx         # NEW
    │       ├── KeywordTable.jsx        # NEW
    │       ├── OpportunityBadge.jsx    # NEW
    │       ├── ArticleEditor.jsx       # NEW
    │       └── GeneratingLoader.jsx    # NEW
    └── pages/
        └── App/
            ├── Projects/
            │   ├── Index.jsx           # NEW: List all projects
            │   ├── Show.jsx            # NEW: Keyword opportunities for project
            │   ├── New.jsx             # NEW: Create project
            │   └── Edit.jsx            # NEW: Edit project
            ├── Keywords/
            │   └── Show.jsx            # NEW: Keyword detail before generating
            └── Articles/
                ├── Show.jsx            # NEW: View/edit article
                └── Generating.jsx      # NEW: Loading screen
```

---

## Data Models

### Existing: User (from template)
```ruby
# Provided by Rails 8 auth + template enhancements
class User < ApplicationRecord
  pay_customer default_payment_processor: :stripe

  # Fields from template:
  # - email_address:string (via Rails auth)
  # - password_digest:string (via Rails auth)
  # - first_name:string
  # - last_name:string
  # - email_verified_at:datetime
  # - oauth_provider:string
  # - oauth_uid:string

  has_many :projects, dependent: :destroy
  has_many :subscriptions # via pay gem

  # Template provides:
  # - full_name, initials
  # - email_verified?
  # - plan_name, current_subscription, free_plan?, paid_plan?
  # - job_priority (paid users = 10, free = 5)
end
```

### NEW: Project
```ruby
class Project < ApplicationRecord
  belongs_to :user
  has_many :competitors, dependent: :destroy
  has_many :keyword_researches, dependent: :destroy
  has_many :keywords, through: :keyword_researches
  has_many :articles, dependent: :destroy

  validates :name, presence: true
  validates :domain, presence: true, format: { with: URI::regexp(%w[http https]) }

  # Fields:
  # - name:string (e.g., "My SaaS Landing Page")
  # - domain:string (e.g., "https://signallab.app")
  # - niche:string (e.g., "SaaS tools for indie hackers")
  # - tone_of_voice:string (e.g., "Professional", "Casual", "Friendly")
  # - call_to_actions:jsonb (array of {text, url} pairs)
  # - sitemap_url:string (optional, for faster content discovery)
  # - created_at:datetime
  # - updated_at:datetime

  # Tone of voice options
  TONE_OPTIONS = [
    "Professional",
    "Casual",
    "Friendly",
    "Authoritative",
    "Conversational"
  ].freeze

  def default_cta
    call_to_actions&.first
  end
end
```

### NEW: Competitor
```ruby
class Competitor < ApplicationRecord
  belongs_to :project

  validates :domain, presence: true

  # Fields:
  # - domain:string (e.g., "founderpal.ai")
  # - auto_detected:boolean (true if found automatically)
  # - created_at:datetime
  # - updated_at:datetime
end
```

### NEW: KeywordResearch
```ruby
class KeywordResearch < ApplicationRecord
  belongs_to :project
  has_many :keywords, dependent: :destroy

  enum status: { pending: 0, processing: 1, completed: 2, failed: 3 }

  # Fields:
  # - status:integer (enum)
  # - seed_keywords:text[] (PostgreSQL array)
  # - total_keywords_found:integer
  # - started_at:datetime
  # - completed_at:datetime
  # - error_message:text
  # - created_at:datetime
  # - updated_at:datetime

  def retry!
    update!(status: :pending, error_message: nil)
    KeywordResearchJob.perform_later(id)
  end
end
```

### NEW: Keyword
```ruby
class Keyword < ApplicationRecord
  belongs_to :keyword_research
  has_one :article, dependent: :destroy
  has_one :project, through: :keyword_research

  validates :keyword, presence: true

  enum generation_status: {
    not_started: 0,
    queued: 1,
    generating: 2,
    completed: 3,
    failed: 4
  }

  scope :published, -> { where(published: true) }
  scope :unpublished, -> { where(published: false) }
  scope :by_opportunity, -> { order(opportunity: :desc) }
  scope :starred, -> { where(starred: true) }
  scope :recommended, -> { where('opportunity >= ?', 70) }
  scope :queued_for_generation, -> { where(queued_for_generation: true) }
  scope :scheduled, -> { where.not(scheduled_for: nil) }

  # Fields:
  # - keyword:string (e.g., "how to validate startup idea")
  # - volume:integer (estimated monthly searches)
  # - difficulty:integer (0-100, lower = easier)
  # - opportunity:integer (0-100, our recommendation)
  # - cpc:decimal (estimated cost-per-click)
  # - intent:string (informational, commercial, etc.)
  # - sources:text[] (where found: autocomplete, reddit, etc.)
  # - published:boolean (user marked as published)
  # - starred:boolean (user favorited this keyword)
  # - queued_for_generation:boolean (added to generation queue)
  # - scheduled_for:datetime (scheduled for future article generation)
  # - generation_status:integer (enum: not_started, queued, generating, completed, failed)
  # - created_at:datetime
  # - updated_at:datetime

  def easy_win?
    opportunity >= 70
  end

  def medium_opportunity?
    opportunity >= 50 && opportunity < 70
  end

  def difficulty_level
    return "Low" if difficulty < 33
    return "Medium" if difficulty < 66
    "High"
  end

  def difficulty_badge_color
    return "🟢" if difficulty < 33  # Easy/Low
    return "🟡" if difficulty < 66  # Medium
    "🔴"  # Hard/High
  end
end
```

### NEW: Article
```ruby
class Article < ApplicationRecord
  belongs_to :keyword
  belongs_to :project

  enum status: { pending: 0, generating: 1, completed: 2, failed: 3 }

  validates :keyword_id, uniqueness: true # One article per keyword

  # Fields:
  # - title:string (SEO-optimized title)
  # - meta_description:string (155 chars)
  # - content:text (full markdown article)
  # - outline:jsonb (structured outline data)
  # - serp_data:jsonb (competitive analysis)
  # - status:integer (enum)
  # - word_count:integer
  # - target_word_count:integer
  # - generation_cost:decimal (AI API cost in USD)
  # - started_at:datetime
  # - completed_at:datetime
  # - error_message:text
  # - created_at:datetime
  # - updated_at:datetime

  def retry!
    update!(status: :pending, error_message: nil)
    ArticleGenerationJob.perform_later(id)
  end

  def export_markdown
    content
  end

  def export_html
    # Use a markdown processor (e.g., kramdown)
    require 'kramdown'
    Kramdown::Document.new(content).to_html
  end
end
```

---

## Database Schema

```ruby
# New migrations to add to the template

create_table "projects", force: :cascade do |t|
  t.bigint "user_id", null: false
  t.string "name", null: false
  t.string "domain", null: false
  t.string "niche"
  t.string "tone_of_voice"
  t.jsonb "call_to_actions", default: []
  t.string "sitemap_url"
  t.datetime "created_at", null: false
  t.datetime "updated_at", null: false
  t.index ["user_id"], name: "index_projects_on_user_id"
end

create_table "competitors", force: :cascade do |t|
  t.bigint "project_id", null: false
  t.string "domain", null: false
  t.boolean "auto_detected", default: false
  t.datetime "created_at", null: false
  t.datetime "updated_at", null: false
  t.index ["project_id"], name: "index_competitors_on_project_id"
end

create_table "keyword_researches", force: :cascade do |t|
  t.bigint "project_id", null: false
  t.integer "status", default: 0, null: false
  t.text "seed_keywords", array: true, default: []
  t.integer "total_keywords_found"
  t.datetime "started_at"
  t.datetime "completed_at"
  t.text "error_message"
  t.datetime "created_at", null: false
  t.datetime "updated_at", null: false
  t.index ["project_id"], name: "index_keyword_researches_on_project_id"
  t.index ["status"], name: "index_keyword_researches_on_status"
end

create_table "keywords", force: :cascade do |t|
  t.bigint "keyword_research_id", null: false
  t.string "keyword", null: false
  t.integer "volume"
  t.integer "difficulty"
  t.integer "opportunity"
  t.decimal "cpc", precision: 10, scale: 2
  t.string "intent"
  t.text "sources", array: true, default: []
  t.boolean "published", default: false
  t.boolean "starred", default: false
  t.boolean "queued_for_generation", default: false
  t.datetime "scheduled_for"
  t.integer "generation_status", default: 0, null: false
  t.datetime "created_at", null: false
  t.datetime "updated_at", null: false
  t.index ["keyword_research_id"], name: "index_keywords_on_keyword_research_id"
  t.index ["opportunity"], name: "index_keywords_on_opportunity"
  t.index ["published"], name: "index_keywords_on_published"
  t.index ["starred"], name: "index_keywords_on_starred"
  t.index ["queued_for_generation"], name: "index_keywords_on_queued_for_generation"
  t.index ["generation_status"], name: "index_keywords_on_generation_status"
end

create_table "articles", force: :cascade do |t|
  t.bigint "keyword_id", null: false
  t.bigint "project_id", null: false
  t.string "title"
  t.string "meta_description"
  t.text "content"
  t.jsonb "outline"
  t.jsonb "serp_data"
  t.integer "status", default: 0, null: false
  t.integer "word_count"
  t.integer "target_word_count"
  t.decimal "generation_cost", precision: 10, scale: 4
  t.datetime "started_at"
  t.datetime "completed_at"
  t.text "error_message"
  t.datetime "created_at", null: false
  t.datetime "updated_at", null: false
  t.index ["keyword_id"], name: "index_articles_on_keyword_id", unique: true
  t.index ["project_id"], name: "index_articles_on_project_id"
  t.index ["status"], name: "index_articles_on_status"
end

add_foreign_key "projects", "users"
add_foreign_key "competitors", "projects"
add_foreign_key "keyword_researches", "projects"
add_foreign_key "keywords", "keyword_researches"
add_foreign_key "articles", "keywords"
add_foreign_key "articles", "projects"
```

---

## Service Architecture

### Adapted from bin/ Scripts

#### KeywordResearchService
Adapts `bin/keyword_research` logic into a Rails service.

```ruby
# app/services/keyword_research_service.rb
class KeywordResearchService
  def initialize(keyword_research)
    @keyword_research = keyword_research
    @project = keyword_research.project
    @keywords = {}
  end

  def perform
    # 1. Generate seed keywords from project domain + competitors
    generate_seed_keywords

    # 2. Expand via Google autocomplete, PAA, related searches
    expand_keywords

    # 3. Mine Reddit topics
    mine_reddit

    # 4. Scrape competitor sitemaps and pages
    analyze_competitors

    # 5. Get metrics (Google Ads API or heuristics)
    calculate_metrics

    # 6. Save top 30 keywords to database
    save_keywords

    # 7. Mark research as completed
    @keyword_research.update!(
      status: :completed,
      total_keywords_found: @keywords.size,
      completed_at: Time.current
    )
  end

  private

  def generate_seed_keywords
    # Use project domain and competitors to generate seeds
    # Adapted from SeedKeywordGenerator
  end

  def expand_keywords
    # Google autocomplete, PAA, related searches
    # Adapted from bin/keyword_research expand_keywords
  end

  def mine_reddit
    # Extract keywords from Reddit
    # Adapted from mine_reddit_topics
  end

  def analyze_competitors
    # Scrape competitor sitemaps and pages
    # Adapted from analyze_competitors
  end

  def calculate_metrics
    # Get keyword metrics (volume, difficulty, CPC)
    # Adapted from calculate_metrics
  end

  def save_keywords
    # Save top 30 to Keyword model
    sorted = @keywords.values.sort_by { |kw| -kw[:opportunity] }.first(30)

    sorted.each do |kw_data|
      @keyword_research.keywords.create!(
        keyword: kw_data[:keyword],
        volume: kw_data[:volume],
        difficulty: kw_data[:difficulty],
        opportunity: kw_data[:opportunity],
        cpc: kw_data[:cpc],
        intent: kw_data[:intent],
        sources: kw_data[:sources]
      )
    end
  end
end
```

**Sub-services:**
- `GoogleSuggestionsService` - Fetch Google autocomplete
- `SerpScraperService` - Scrape PAA, related searches
- `RedditMinerService` - Mine Reddit for topics
- `CompetitorAnalysisService` - Scrape competitor sitemaps
- `KeywordMetricsService` - Get keyword metrics

#### ArticleGenerationService
Adapts `bin/generate_article` logic into a Rails service.

```ruby
# app/services/article_generation_service.rb
class ArticleGenerationService
  def initialize(article)
    @article = article
    @keyword = article.keyword
    @costs = []
  end

  def perform
    # 1. Research SERP (Google Custom Search + scraping)
    serp_data = research_serp
    @article.update!(serp_data: serp_data[:data])
    log_cost("SERP Research", serp_data[:cost])

    # 2. Generate outline via Gemini
    outline = generate_outline(serp_data[:data])
    @article.update!(outline: outline[:data])
    log_cost("Outline Generation", outline[:cost])

    # 3. Write article sections via GPT-4o
    content = write_article(outline[:data])
    log_cost("Article Writing", content[:cost])

    # 4. Run 3 improvement passes
    improved = improve_article(content[:data], outline[:data])
    log_cost("Improvements", improved[:cost])

    # 5. Save final article
    @article.update!(
      content: improved[:data],
      title: outline[:data]['title'],
      meta_description: outline[:data]['meta_description'],
      word_count: improved[:data].split.size,
      target_word_count: outline[:data]['target_word_count'],
      generation_cost: total_cost,
      status: :completed,
      completed_at: Time.current
    )
  end

  private

  def research_serp
    SerpResearchService.new(@keyword.keyword).perform
  end

  def generate_outline(serp_data)
    client = Ai::ClientService.for_outline_generation

    prompt = <<~PROMPT
      Create a detailed article outline for "#{@keyword.keyword}".

      SERP Analysis:
      #{serp_data.to_json}

      Output as JSON with: title, meta_description, sections...
    PROMPT

    response = client.chat(
      messages: [{ role: "user", content: prompt }],
      system_prompt: "You are an expert SEO content strategist.",
      max_tokens: 8000
    )

    if response[:success]
      outline_json = extract_json(response[:content])
      { data: JSON.parse(outline_json), cost: 0.01 }
    else
      { data: nil, cost: 0 }
    end
  end

  def write_article(outline)
    client = Ai::ClientService.for_article_writing

    # Write intro, sections, conclusion using GPT-4o Mini
    # Adapted from write_article in bin/generate_article
    # Returns: { data: "markdown content", cost: 0.15 }
  end

  def improve_article(content, outline)
    client = Ai::ClientService.for_article_improvement

    # Run 3 improvement passes with GPT-4o Mini
    # Adapted from improve_article in bin/generate_article
    # Returns: { data: "improved content", cost: 0.05 }
  end

  def extract_json(text)
    # Extract JSON from markdown code blocks
    text[/```json\s*(.+?)\s*```/m, 1] || text
  end

  def total_cost
    @costs.sum { |c| c[:amount] }
  end

  def log_cost(step, amount)
    @costs << { step: step, amount: amount }
  end
end
```

**Sub-services:**
- `SerpResearchService` - Google search + article scraping + analysis
- `ArticleOutlineService` - Generate outline with Gemini
- `ArticleWriterService` - Write sections with GPT-4o
- `ArticleImprovementService` - Polish article with GPT-4o
- `VoiceAnalysisService` - Optional voice matching (future)

#### ProjectAutofillService
Scrapes a website URL to auto-populate project details.

```ruby
# app/services/project_autofill_service.rb
class ProjectAutofillService
  def initialize(domain)
    @domain = domain
  end

  def perform
    # 1. Fetch homepage HTML
    html = fetch_page(@domain)
    return {} if html.blank?

    # 2. Extract metadata
    name = extract_title(html)
    description = extract_description(html)
    niche = infer_niche(description, html)

    {
      name: name,
      niche: niche
    }
  end

  private

  def fetch_page(url)
    response = Net::HTTP.get_response(URI(url))
    response.body if response.is_a?(Net::HTTPSuccess)
  rescue => e
    Rails.logger.error "ProjectAutofillService error: #{e.message}"
    nil
  end

  def extract_title(html)
    doc = Nokogiri::HTML(html)
    doc.at_css('title')&.text&.strip ||
      doc.at_css('meta[property="og:title"]')&.[]('content') ||
      doc.at_css('h1')&.text&.strip
  end

  def extract_description(html)
    doc = Nokogiri::HTML(html)
    doc.at_css('meta[name="description"]')&.[]('content') ||
      doc.at_css('meta[property="og:description"]')&.[]('content')
  end

  def infer_niche(description, html)
    # Use AI to infer niche from description and page content
    client = Ai::ClientService.for_keyword_analysis

    prompt = <<~PROMPT
      Based on this website description, identify the business niche in 3-5 words:

      Description: #{description}

      Respond with only the niche (e.g., "SaaS tools for developers", "E-commerce fashion")
    PROMPT

    response = client.chat(
      messages: [{ role: "user", content: prompt }],
      max_tokens: 50
    )

    response[:success] ? response[:content].strip : nil
  end
end
```

#### CompetitorFinderService
Auto-discovers competitor domains based on project domain and niche.

```ruby
# app/services/competitor_finder_service.rb
class CompetitorFinderService
  def initialize(project)
    @project = project
  end

  def perform
    competitors = []

    # 1. Search Google for "{niche} tools" or similar
    query = build_search_query
    results = google_search(query)

    # 2. Extract domains from top 10 results
    results.each do |result|
      domain = extract_domain(result['link'])
      next if domain == extract_domain(@project.domain)
      next if competitors.map { |c| c[:domain] }.include?(domain)

      competitors << {
        domain: domain,
        auto_detected: true
      }
      break if competitors.size >= 5
    end

    # 3. Save to database
    competitors.each do |comp_data|
      @project.competitors.find_or_create_by(domain: comp_data[:domain]) do |c|
        c.auto_detected = comp_data[:auto_detected]
      end
    end

    competitors.size
  end

  private

  def build_search_query
    if @project.niche.present?
      "#{@project.niche} alternatives"
    else
      # Extract domain name for search
      domain_name = @project.domain.gsub(/https?:\/\//, '').gsub(/www\./, '').split('.').first
      "#{domain_name} competitors alternatives"
    end
  end

  def google_search(query)
    # Use Google Custom Search API
    uri = URI(GOOGLE_SEARCH_ENDPOINT)
    params = {
      key: ENV['GOOGLE_SEARCH_KEY'],
      cx: ENV['GOOGLE_SEARCH_CX'],
      q: query,
      num: 10
    }
    uri.query = URI.encode_www_form(params)

    response = Net::HTTP.get_response(uri)
    if response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body)['items'] || []
    else
      []
    end
  rescue => e
    Rails.logger.error "CompetitorFinderService error: #{e.message}"
    []
  end

  def extract_domain(url)
    uri = URI(url)
    "#{uri.scheme}://#{uri.host}"
  rescue
    url
  end
end
```

#### KeywordCategorizationService
Categorizes keywords based on opportunity score and other criteria.

```ruby
# app/services/keyword_categorization_service.rb
class KeywordCategorizationService
  def initialize(keyword_research)
    @keyword_research = keyword_research
  end

  def recommended_keywords
    @keyword_research.keywords.where('opportunity >= ?', 70).by_opportunity
  end

  def starred_keywords
    @keyword_research.keywords.starred.by_opportunity
  end

  def queued_keywords
    @keyword_research.keywords.queued_for_generation.by_opportunity
  end

  def generated_keywords
    @keyword_research.keywords.where(generation_status: :completed).by_opportunity
  end

  def failed_keywords
    @keyword_research.keywords.where(generation_status: :failed).by_opportunity
  end

  def all_keywords
    @keyword_research.keywords.by_opportunity
  end

  def categorize_all
    {
      all: all_keywords,
      recommended: recommended_keywords,
      starred: starred_keywords,
      queued: queued_keywords,
      generated: generated_keywords,
      failed: failed_keywords
    }
  end
end
```

---

## Background Jobs

### KeywordResearchJob
```ruby
# app/jobs/keyword_research_job.rb
class KeywordResearchJob < ApplicationJob
  queue_as :default

  def perform(keyword_research_id)
    keyword_research = KeywordResearch.find(keyword_research_id)
    keyword_research.update!(status: :processing, started_at: Time.current)

    KeywordResearchService.new(keyword_research).perform
  rescue => e
    keyword_research.update!(
      status: :failed,
      error_message: e.message,
      completed_at: Time.current
    )
    raise
  end
end
```

**Estimated Duration:** 5-10 minutes
**Priority:** Uses `user.job_priority` (paid users = 10, free = 5)

### ArticleGenerationJob
```ruby
# app/jobs/article_generation_job.rb
class ArticleGenerationJob < ApplicationJob
  queue_as :default

  def perform(article_id)
    article = Article.find(article_id)
    article.update!(status: :generating, started_at: Time.current)

    ArticleGenerationService.new(article).perform
  rescue => e
    article.update!(
      status: :failed,
      error_message: e.message,
      completed_at: Time.current
    )
    raise
  end
end
```

**Estimated Duration:** 2-3 minutes
**Cost Tracking:** Logs to `article.generation_cost`
**Priority:** Uses `user.job_priority`

---

## API Integration

### AI Provider: ruby_llm
We use the [ruby_llm](https://rubyllm.com) gem as a unified wrapper for all AI providers (OpenAI, Gemini, Anthropic, etc.). This provides a consistent interface and easy provider switching.

**Setup:**
```ruby
# config/initializers/ruby_llm.rb
# ruby_llm automatically reads API keys from ENV:
# - OPENAI_API_KEY
# - GEMINI_API_KEY
# - ANTHROPIC_API_KEY (optional future use)
```

**Ai::ClientService** - Centralized AI service configuration:
```ruby
# app/services/ai/client_service.rb
class Ai::ClientService
  # Model configuration for different services
  MODELS = {
    keyword_analysis: { provider: "gemini", model: "gemini-2.5-flash" },
    outline_generation: { provider: "gemini", model: "gemini-2.5-flash" },
    article_writing: { provider: "openai", model: "gpt-4o-mini" },
    article_improvement: { provider: "openai", model: "gpt-4o-mini" },
    serp_analysis: { provider: "gemini", model: "gemini-2.5-flash" }
  }.freeze

  def initialize(service_name)
    config = MODELS[service_name]
    @provider = config[:provider]
    @model = config[:model]
  end

  def chat(messages:, max_tokens: 1000, temperature: 0.7, system_prompt: nil)
    Rails.logger.info "AI Request: #{@provider}/#{@model} (tokens: #{max_tokens})"

    begin
      chat = RubyLLM.chat(provider: @provider, model: @model)
                    .with_temperature(temperature)

      # Provider-specific parameters
      case @provider
      when "gemini"
        chat = chat.with_params(generationConfig: {
          maxOutputTokens: max_tokens
        })
      else
        chat = chat.with_params(max_tokens: max_tokens)
      end

      # Add system instructions
      chat = chat.with_instructions(system_prompt) if system_prompt.present?

      # Get response
      prompt = messages.last[:content]
      response = chat.ask(prompt)

      { success: true, content: response.content }

    rescue RubyLLM::UnauthorizedError => e
      Rails.logger.error "AI Auth Error: #{e.message}"
      { success: false, error: "Authentication failed" }
    rescue RubyLLM::RateLimitError => e
      Rails.logger.warn "AI Rate Limit: #{e.message}"
      { success: false, error: "Rate limit exceeded" }
    rescue => e
      Rails.logger.error "AI Error: #{e.message}"
      { success: false, error: e.message }
    end
  end

  # Convenience constructors
  def self.for_keyword_analysis
    new(:keyword_analysis)
  end

  def self.for_outline_generation
    new(:outline_generation)
  end

  def self.for_article_writing
    new(:article_writing)
  end

  def self.for_article_improvement
    new(:article_improvement)
  end

  def self.for_serp_analysis
    new(:serp_analysis)
  end
end
```

**Usage Example:**
```ruby
# In a service
client = Ai::ClientService.for_article_writing
response = client.chat(
  messages: [{ role: "user", content: "Write an intro about..." }],
  system_prompt: "You are an expert SEO writer...",
  max_tokens: 4000,
  temperature: 0.7
)

if response[:success]
  content = response[:content]
else
  # Handle error
  error = response[:error]
end
```

**Cost per article:**
- SERP Analysis (Gemini 2.5 Flash): ~$0.01
- Outline Generation (Gemini 2.5 Flash): ~$0.01
- Article Writing (GPT-4o Mini): ~$0.15
- Improvements (GPT-4o Mini 3x): ~$0.05
- **Total:** ~$0.22 per article

### Google Custom Search API
**Usage:** Fetch top 10 SERP results

```ruby
# Direct HTTP calls (no gem needed)
GOOGLE_SEARCH_ENDPOINT = 'https://www.googleapis.com/customsearch/v1'
```

**Limits:** 100 queries/day (free), 10,000/day (paid $5/1000 queries)

---

## Controllers

### ProjectsController
```ruby
class ProjectsController < ApplicationController
  before_action :set_project, only: [:show, :edit, :update, :destroy]

  def index
    projects = Current.user.projects.order(created_at: :desc)
    render inertia: 'App/Projects/Index', props: { projects: projects }
  end

  def show
    latest_research = @project.keyword_researches.order(created_at: :desc).first
    keywords = latest_research&.keywords&.by_opportunity || []

    render inertia: 'App/Projects/Show', props: {
      project: @project,
      keywords: keywords,
      hasResearch: latest_research.present?,
      isProcessing: latest_research&.processing?
    }
  end

  def new
    render inertia: 'App/Projects/New'
  end

  def create
    project = Current.user.projects.new(project_params)

    if project.save
      # Auto-detect competitors
      CompetitorDetectionService.new(project).perform

      # Start keyword research
      research = project.keyword_researches.create!(status: :pending)
      KeywordResearchJob.set(priority: Current.user.job_priority).perform_later(research.id)

      redirect_to project_path(project), notice: "Project created! Researching keywords..."
    else
      render inertia: 'App/Projects/New', props: { errors: project.errors.full_messages }
    end
  end

  private

  def set_project
    @project = Current.user.projects.find(params[:id])
  end

  def project_params
    params.require(:project).permit(:name, :domain)
  end
end
```

### ArticlesController
```ruby
class ArticlesController < ApplicationController
  def create
    keyword = Keyword.find(params[:keyword_id])
    project = keyword.keyword_research.project

    # Ensure user owns this project
    return redirect_to root_path, alert: "Unauthorized" unless project.user == Current.user

    # Create article
    article = Article.create!(
      keyword: keyword,
      project: project,
      status: :pending
    )

    # Start generation job with user's priority
    ArticleGenerationJob.set(priority: Current.user.job_priority).perform_later(article.id)

    redirect_to article_path(article), notice: "Generating article..."
  end

  def show
    @article = Article.find(params[:id])

    # Ensure user owns this article
    return redirect_to root_path, alert: "Unauthorized" unless @article.project.user == Current.user

    render inertia: 'App/Articles/Show', props: {
      article: {
        id: @article.id,
        title: @article.title,
        meta_description: @article.meta_description,
        content: @article.content,
        word_count: @article.word_count,
        target_word_count: @article.target_word_count,
        status: @article.status,
        generation_cost: @article.generation_cost,
        keyword: @article.keyword.keyword
      }
    }
  end

  def export
    article = Article.find(params[:id])
    return redirect_to root_path, alert: "Unauthorized" unless article.project.user == Current.user

    case params[:format]
    when 'markdown'
      send_data article.export_markdown, filename: "#{article.keyword.keyword.parameterize}.md", type: 'text/markdown'
    when 'html'
      send_data article.export_html, filename: "#{article.keyword.keyword.parameterize}.html", type: 'text/html'
    else
      redirect_to article_path(article), alert: "Invalid format"
    end
  end
end
```

---

## Frontend Components

### KeywordTable
```jsx
// app/frontend/components/app/KeywordTable.jsx
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { router } from "@inertiajs/react";

export default function KeywordTable({ keywords, projectId }) {
  const getOpportunityColor = (score) => {
    if (score >= 70) return "bg-green-100 text-green-800";
    if (score >= 50) return "bg-yellow-100 text-yellow-800";
    return "bg-red-100 text-red-800";
  };

  const handleGenerateArticle = (keywordId) => {
    router.post(`/projects/${projectId}/articles`, { keyword_id: keywordId });
  };

  return (
    <div className="overflow-x-auto">
      <table className="w-full">
        <thead>
          <tr className="border-b">
            <th className="text-left p-3">Keyword</th>
            <th className="text-right p-3">Volume</th>
            <th className="text-right p-3">Difficulty</th>
            <th className="text-right p-3">Opportunity</th>
            <th className="text-left p-3">Intent</th>
            <th className="text-right p-3">Actions</th>
          </tr>
        </thead>
        <tbody>
          {keywords.map((kw) => (
            <tr key={kw.id} className="border-b hover:bg-muted/50">
              <td className="p-3 font-medium">{kw.keyword}</td>
              <td className="text-right p-3">{kw.volume.toLocaleString()}</td>
              <td className="text-right p-3">{kw.difficulty}</td>
              <td className="text-right p-3">
                <Badge className={getOpportunityColor(kw.opportunity)}>
                  {kw.opportunity}
                </Badge>
              </td>
              <td className="p-3 capitalize">{kw.intent}</td>
              <td className="text-right p-3">
                {kw.article ? (
                  <Button variant="outline" size="sm" onClick={() => router.visit(`/articles/${kw.article.id}`)}>
                    View Article
                  </Button>
                ) : (
                  <Button size="sm" onClick={() => handleGenerateArticle(kw.id)}>
                    Generate Article
                  </Button>
                )}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
```

### ArticleEditor
```jsx
// app/frontend/components/app/ArticleEditor.jsx
import { useState } from "react";
import { Button } from "@/components/ui/button";
import { Textarea } from "@/components/ui/textarea";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";

export default function ArticleEditor({ article }) {
  const [content, setContent] = useState(article.content);

  const handleCopyToClipboard = () => {
    navigator.clipboard.writeText(content);
    alert("Copied to clipboard!");
  };

  const handleDownload = (format) => {
    window.location.href = `/articles/${article.id}/export?format=${format}`;
  };

  return (
    <div className="space-y-6">
      <Card>
        <CardHeader>
          <CardTitle>Article Content</CardTitle>
        </CardHeader>
        <CardContent>
          <Textarea
            value={content}
            onChange={(e) => setContent(e.target.value)}
            rows={30}
            className="font-mono"
          />
        </CardContent>
      </Card>

      <div className="flex gap-3">
        <Button onClick={handleCopyToClipboard}>Copy to Clipboard</Button>
        <Button variant="outline" onClick={() => handleDownload('markdown')}>
          Download Markdown
        </Button>
        <Button variant="outline" onClick={() => handleDownload('html')}>
          Download HTML
        </Button>
      </div>
    </div>
  );
}
```

---

## Cost Analysis

### Target Cost Per Article
- SERP Research (Gemini 2.5 Flash): $0.01
- Outline Generation (Gemini 2.5 Flash): $0.01
- Article Writing (GPT-4o Mini): $0.15
- Improvements (GPT-4o Mini 3x): $0.05
- **Total:** ~$0.22 per article

### Pricing Strategy
**Option 1: Simple Monthly**
- Free: 1 project, 5 articles/month = $1.10 cost → **Price: $0**
- Pro ($29/month): 3 projects, 20 articles/month = $4.40 cost → **85% margin**
- Premium ($79/month): 10 projects, 50 articles/month = $11 cost → **86% margin**

**Option 2: Pay Per Article**
- $3 per article generated = **93% margin**
- Packs: 10 for $25 ($2.50/article) = **91% margin**

**Option 3: Hybrid**
- Free: 1 project, 3 articles/month
- Pro ($19/month): 3 projects, 15 articles/month → **88% margin**
- Premium ($49/month): Unlimited projects, 50 articles/month → **78% margin**

**Recommendation:** Option 3 (Hybrid) gives excellent margins while keeping prices attractive. With GPT-4o Mini costs, we can be very aggressive on pricing and still maintain 85%+ margins.

---

## Environment Variables

```bash
# .env additions beyond template

# AI APIs (required by ruby_llm)
OPENAI_API_KEY=sk-...           # For GPT-4o Mini (article writing)
GEMINI_API_KEY=...              # For Gemini 2.5 Flash (analysis)
# ANTHROPIC_API_KEY=...         # Optional (future use)

# Google Search
GOOGLE_SEARCH_KEY=...           # Google Custom Search API
GOOGLE_SEARCH_CX=...            # Search Engine ID

# Optional: Google Ads API (for real keyword metrics)
GOOGLE_ADS_DEVELOPER_TOKEN=...
GOOGLE_ADS_CLIENT_ID=...
GOOGLE_ADS_CLIENT_SECRET=...
GOOGLE_ADS_REFRESH_TOKEN=...
```

---

## Deployment Checklist

### 1. Create New Rails App from Template
```bash
rails new verysimpleseo -m docs/template-enhanced.rb -d postgresql --skip-javascript
cd verysimpleseo
```

### 2. Add VerySimpleSEO Features
```bash
# Generate models
rails g model Project user:references name:string domain:string
rails g model Competitor project:references domain:string auto_detected:boolean
rails g model KeywordResearch project:references status:integer seed_keywords:text total_keywords_found:integer started_at:datetime completed_at:datetime error_message:text
rails g model Keyword keyword_research:references keyword:string volume:integer difficulty:integer opportunity:integer cpc:decimal intent:string sources:text published:boolean
rails g model Article keyword:references project:references title:string meta_description:string content:text outline:jsonb serp_data:jsonb status:integer word_count:integer target_word_count:integer generation_cost:decimal started_at:datetime completed_at:datetime error_message:text

# Migrate
rails db:migrate

# Add services, jobs, controllers (copy from bin/ adaptations)
```

### 3. Configure Environment
```bash
cp .env.example .env
# Add all API keys
```

### 4. Deploy to Fly.io
```bash
fly launch
fly secrets set OPENAI_API_KEY=... GEMINI_API_KEY=... GOOGLE_SEARCH_KEY=...
fly deploy
```

---

## Testing Strategy

### Unit Tests (Minitest)
- Service objects: `test/services/keyword_research_service_test.rb`
- Models: validations, associations, scopes
- Jobs: behavior, error handling

### Integration Tests
- Controllers: project CRUD, keyword research trigger, article generation
- End-to-end flows: signup → create project → research → generate article

### External API Mocking
```ruby
# test/test_helper.rb
class ActiveSupport::TestCase
  setup do
    stub_google_search_api
    stub_ruby_llm_responses
  end

  private

  def stub_ruby_llm_responses
    # Stub RubyLLM chat responses
    allow_any_instance_of(RubyLLM::Chat).to receive(:ask).and_return(
      double(content: "Mocked AI response")
    )
  end

  def stub_google_search_api
    # Stub Google Custom Search API
  end
end
```

---

## Security Considerations

### Authorization
- All project-related actions check `Current.user.projects.find(params[:id])`
- Articles can only be viewed/edited by owner
- Background jobs validate ownership before processing

### Rate Limiting
- Apply rack-attack to prevent abuse of keyword research
- Limit free users to 5 articles/month
- Paid users get unlimited (or higher limit)

### Secrets Management
- Never log API keys or article content to external services
- Use Rails credentials for production secrets
- Stripe webhooks verify signature

---

## Performance Optimization

### Database
- Index on `keywords.opportunity` for fast sorting
- JSONB for flexible outline/serp_data storage
- Pagination for keyword tables (30 default, expand if needed)

### Caching
- Cache Google search results for 24 hours
- Cache competitor analysis for 7 days
- Use Rails.cache for repeated API calls

### Background Jobs
- Use Solid Queue priorities (paid users = 10, free = 5)
- Sleep between external API requests (avoid rate limits)
- Implement exponential backoff for failures

---

## Next Steps

1. **Generate Rails app from template**
2. **Create new models + migrations**
3. **Adapt bin/ scripts into services**
4. **Build background jobs**
5. **Create controllers + Inertia pages**
6. **Add tests for critical paths**
7. **Deploy to Fly.io staging**
8. **Beta test with 10 users**
9. **Launch 🚀**
