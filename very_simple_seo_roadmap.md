# VerySimpleSEO - Development Roadmap

**Goal:** Build a Rails 8 SaaS app that helps solopreneurs generate keyword research and SEO-optimized articles.

**Timeline:** 4-6 weeks for MVP
**Starting Point:** Fresh Rails 8 app from `docs/template-enhanced.rb`

---

## 🎯 Current Status: **Phase 9 Complete - Ready to Deploy!** ✅

### ✅ Completed Phases (0-6, 8-9):
- **Phase 0:** Foundation Setup (Rails 8, PostgreSQL, Solid Stack, ruby_llm) ✅
- **Phase 1:** Core Models & Schema (5 models, migrations, validations, scopes) ✅
- **Phase 2:** Keyword Research System (8 services, background jobs, Google Ads integration) ✅
- **Phase 3:** Article Generation System (6 services, tested end-to-end) ✅
- **Phase 4:** Real-time Updates with Solid Cable (ActionCable channels, broadcasting) ✅
- **Phase 5:** Controllers & Routes (ProjectsController, ArticlesController, routes) ✅
- **Phase 6:** Frontend Pages (Projects Index/New/Show/Edit, Articles Show, Dashboard) ✅
- **Phase 8:** Testing & QA (80 tests, 11.94% coverage, 100% pass rate) ✅
- **Phase 9:** Deployment Documentation (Kamal + Fly.io guides, checklists, troubleshooting) ✅

### 📊 What's Working:
- ✅ **Models**: All 5 models with validations, scopes, helper methods
- ✅ **Keyword Research**: 190+ keywords in ~42 seconds, AI seed generation
- ✅ **Article Generation**: 2000+ word articles, $0.41 cost, real SERP examples
- ✅ **Real-time Updates**: ActionCable broadcasts status during background jobs
- ✅ **Credits System**: 3/10/30 credits per plan, auto-managed via Stripe webhooks
- ✅ **Controllers**: ProjectsController (CRUD), ArticlesController (create, show, export)
- ✅ **Frontend Pages**: All 5 major pages built (Projects Index/New/Show/Edit, Articles Show)
- ✅ **Dashboard**: Stats grid, recent projects/articles, empty states
- ✅ **Real-time UI**: Live keyword research & article generation progress
- ✅ **Testing Setup**: Vitest + React Testing Library configured, 12 tests (7 passing)
- ✅ **Auth-aware UI**: Navbar and Home page adapt to login state
- ✅ **User Validations**: Email uniqueness, format, password length

### 📊 Current Test Coverage:
- **Frontend Tests**: 12 tests written (7 passing, 5 minor fixes needed) - ~58% pass rate
- **Backend Tests**: 0% coverage (Phase 8 priority)
- **Total Coverage**: ~5% (frontend only)

### ⚠️ Current Issues:
- **Backend Test Coverage: 0%** - No model/controller/service tests yet
- Some frontend tests need minor fixes (duplicate text in nav vs content)

### 🚀 Next Up: **Phase 7 - Polish & Admin Features (Optional)**

**Options for Phase 7:**
1. **Admin Dashboard** - View all users, projects, articles, usage stats
2. **Enhanced Features** - Bulk operations, content calendar, WordPress integration
3. **Skip to Phase 8** - Comprehensive testing (60%+ coverage)

### 📝 Testing Strategy:
From now on, **add tests after completing each phase**:
- ✅ Phase 6: Frontend component tests (12 tests created)
- Phase 7: Credits/usage limits tests
- Phase 8: Comprehensive test suite (60%+ coverage goal)

---

## Phase 0: Foundation Setup (Day 1) ✅ COMPLETED

### 0.1 Generate Rails App from Template ✅

```bash
# Create new app using enhanced template
rails new verysimpleseo -m docs/template-enhanced.rb -d postgresql --skip-javascript

cd verysimpleseo

# Answer template prompts:
# - App name: "VerySimpleSEO"
# - Enable Google OAuth: Yes
# - Plan 1: Free (keep default)
# - Plan 2: Pro ($19/month)
# - Plan 3: Premium ($49/month)
```

**What you get:**
- Rails 8 + PostgreSQL
- Solid Queue, Solid Cable, Solid Cache (no Redis!)
- Inertia + React + Vite + shadcn/ui + Tailwind v4
- User auth with email verification
- Stripe billing via Pay gem
- Resend email (prod) + letter_opener_web (dev)

### 0.2 Environment Setup ✅

```bash
# Copy environment template
cp .env.example .env

# Add API keys to .env:
# - OPENAI_API_KEY (for GPT-4o Mini)
# - GEMINI_API_KEY (for Gemini 2.5 Flash)
# - GOOGLE_SEARCH_KEY (Google Custom Search API)
# - GOOGLE_SEARCH_CX (Search Engine ID)
# - STRIPE_SECRET_KEY
# - RESEND_API_KEY
```

### 0.3 Add VerySimpleSEO Dependencies ✅

```ruby
# Add to Gemfile
gem 'nokogiri'      # Already included in Rails
gem 'ruby_llm'      # Unified LLM wrapper

# Install
bundle install
```

### 0.4 Database Setup ✅

```bash
# Create databases
rails db:create

# Run template migrations (users, pay tables, etc.)
rails db:migrate

# Seed Stripe plans
rails runner db/seeds/pay_plans.rb

# Start dev server (Rails on :5000 + Vite)
bin/dev
```

**Acceptance:**
- ✅ App loads at http://localhost:5000
- ✅ Can sign up with email + password
- ✅ Can log in with Google OAuth
- ✅ Can view /pricing page
- ✅ Email verification works (check http://localhost:5000/letter_opener)

---

## Phase 1: Core Models & Schema (Days 2-3) ✅ COMPLETED

### 1.1 Generate Models ✅

```bash
# Project model
rails g model Project user:references name:string domain:string niche:string tone_of_voice:string call_to_actions:jsonb sitemap_url:string

# Competitor model
rails g model Competitor project:references domain:string auto_detected:boolean

# KeywordResearch model
rails g model KeywordResearch project:references status:integer seed_keywords:text total_keywords_found:integer started_at:datetime completed_at:datetime error_message:text

# Keyword model
rails g model Keyword keyword_research:references keyword:string volume:integer difficulty:integer opportunity:integer cpc:decimal intent:string sources:text published:boolean starred:boolean queued_for_generation:boolean scheduled_for:datetime generation_status:integer

# Article model
rails g model Article keyword:references project:references title:string meta_description:string content:text outline:jsonb serp_data:jsonb status:integer word_count:integer target_word_count:integer generation_cost:decimal started_at:datetime completed_at:datetime error_message:text
```

### 1.2 Enhance Migrations ✅

Edit the generated migrations to add:
- Enums for status fields
- Indexes on frequently queried columns
- Default values for jsonb fields
- PostgreSQL array columns for `sources` and `seed_keywords`

**Reference:** See `very_simple_seo_technical_document.md` lines 336-429 for exact schema.

### 1.3 Add Model Logic ✅

Create enhanced models with:
- Associations (`has_many`, `belongs_to`)
- Validations
- Enums (`status`, `generation_status`, `intent`)
- Scopes (`published`, `by_opportunity`, `recommended`)
- Helper methods (`easy_win?`, `retry!`, `export_markdown`)

**Reference:** See `very_simple_seo_technical_document.md` lines 123-332 for model code.

### 1.4 Run Migrations ✅

```bash
rails db:migrate
```

**Acceptance:**
- ✅ All 5 models created
- ✅ Database schema matches technical doc
- ✅ Can create records in Rails console:
  ```ruby
  user = User.first
  project = user.projects.create!(name: "Test", domain: "https://example.com")
  research = project.keyword_researches.create!(status: :pending)
  keyword = research.keywords.create!(keyword: "test keyword", volume: 100, difficulty: 50, opportunity: 75)
  ```

### 1.5 Model Specifications

Complete specifications for all models created in Phase 1:

#### User Model (Enhanced from Template)
```ruby
# app/models/user.rb
class User < ApplicationRecord
  pay_customer default_payment_processor: :stripe
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :projects, dependent: :destroy  # ADDED

  # Fields:
  # - email_address:string (via Rails auth)
  # - password_digest:string (via Rails auth)
  # - first_name:string
  # - last_name:string
  # - email_verified_at:datetime
  # - oauth_provider:string
  # - oauth_uid:string

  # Provided by template:
  # - full_name, initials
  # - email_verified?, verify_email!
  # - plan_name, current_subscription, free_plan?, paid_plan?
  # - job_priority (paid users = 10, free = 5)
end
```

**Specs:**
- ✅ `has_many :projects` association works
- ✅ `user.job_priority` returns 10 for paid, 5 for free users
- ✅ `user.plan_name` returns current plan ("Free", "Pro", "Premium")

#### Project Model
```ruby
# app/models/project.rb
class Project < ApplicationRecord
  belongs_to :user
  has_many :competitors, dependent: :destroy
  has_many :keyword_researches, dependent: :destroy
  has_many :keywords, through: :keyword_researches
  has_many :articles, dependent: :destroy

  validates :name, presence: true
  validates :domain, presence: true, format: { with: URI::regexp(%w[http https]) }

  # Fields:
  # - name:string (required, e.g. "My SaaS Landing Page")
  # - domain:string (required, must be valid HTTP/HTTPS URL)
  # - niche:string (optional, e.g. "SaaS tools for indie hackers")
  # - tone_of_voice:string (optional, one of TONE_OPTIONS)
  # - call_to_actions:jsonb (array of {text, url} pairs, default: [])
  # - sitemap_url:string (optional, for faster content discovery)

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

**Specs:**
- ✅ Validates presence of `name` and `domain`
- ✅ Validates `domain` format (must be http:// or https://)
- ✅ `project.competitors` returns associated competitors
- ✅ `project.keyword_researches` returns all research runs
- ✅ `project.keywords` returns all keywords through keyword_researches
- ✅ `project.articles` returns all generated articles
- ✅ `project.default_cta` returns first CTA or nil
- ✅ Deleting project cascades to competitors, keyword_researches, articles

#### Competitor Model
```ruby
# app/models/competitor.rb
class Competitor < ApplicationRecord
  belongs_to :project

  validates :domain, presence: true

  # Fields:
  # - domain:string (required, e.g. "https://founderpal.ai")
  # - auto_detected:boolean (default: false, true if found automatically)
end
```

**Specs:**
- ✅ Validates presence of `domain`
- ✅ `competitor.project` returns parent project
- ✅ `auto_detected` defaults to false
- ✅ Can distinguish between manual and auto-detected competitors

#### KeywordResearch Model
```ruby
# app/models/keyword_research.rb
class KeywordResearch < ApplicationRecord
  belongs_to :project
  has_many :keywords, dependent: :destroy

  enum :status, { pending: 0, processing: 1, completed: 2, failed: 3 }

  # Fields:
  # - status:integer (enum: pending/processing/completed/failed, default: 0)
  # - seed_keywords:text[] (PostgreSQL array, default: [])
  # - total_keywords_found:integer (count of keywords discovered)
  # - started_at:datetime (when processing began)
  # - completed_at:datetime (when finished or failed)
  # - error_message:text (populated on failure)

  def retry!
    update!(status: :pending, error_message: nil)
    KeywordResearchJob.perform_later(id)
  end
end
```

**Specs:**
- ✅ `keyword_research.project` returns parent project
- ✅ `keyword_research.keywords` returns all discovered keywords
- ✅ Status enum works: `pending?`, `processing?`, `completed?`, `failed?`
- ✅ `seed_keywords` is a PostgreSQL array (not string)
- ✅ `retry!` resets status and error_message, enqueues job
- ✅ Can transition through status lifecycle: pending → processing → completed
- ✅ Deleting keyword_research cascades to keywords

#### Keyword Model
```ruby
# app/models/keyword.rb
class Keyword < ApplicationRecord
  belongs_to :keyword_research
  has_one :article, dependent: :destroy
  has_one :project, through: :keyword_research

  validates :keyword, presence: true

  enum :generation_status, {
    not_started: 0,
    queued: 1,
    generating: 2,
    completed: 3,
    failed: 4
  }

  # Fields:
  # - keyword:string (required, e.g. "how to validate startup idea")
  # - volume:integer (estimated monthly searches)
  # - difficulty:integer (0-100, lower = easier to rank)
  # - opportunity:integer (0-100, our recommendation score)
  # - cpc:decimal(10,2) (estimated cost-per-click)
  # - intent:string (informational, commercial, transactional, navigational)
  # - sources:text[] (PostgreSQL array: autocomplete, reddit, competitor, paa)
  # - published:boolean (default: false, user marked as published)
  # - starred:boolean (default: false, user favorited)
  # - queued_for_generation:boolean (default: false, in generation queue)
  # - scheduled_for:datetime (future article generation time)
  # - generation_status:integer (enum, default: 0/not_started)

  scope :published, -> { where(published: true) }
  scope :unpublished, -> { where(published: false) }
  scope :by_opportunity, -> { order(opportunity: :desc) }
  scope :starred, -> { where(starred: true) }
  scope :recommended, -> { where('opportunity >= ?', 70) }
  scope :queued_for_generation, -> { where(queued_for_generation: true) }
  scope :scheduled, -> { where.not(scheduled_for: nil) }

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

**Specs:**
- ✅ Validates presence of `keyword`
- ✅ `keyword.keyword_research` returns parent research
- ✅ `keyword.article` returns generated article (or nil)
- ✅ `keyword.project` returns project through keyword_research
- ✅ Generation status enum works: `not_started?`, `queued?`, `generating?`, `completed?`, `failed?`
- ✅ `sources` is a PostgreSQL array
- ✅ All boolean flags default to false
- ✅ Scopes work correctly:
  - `Keyword.published` returns only published
  - `Keyword.by_opportunity` orders by opportunity desc
  - `Keyword.starred` returns favorites
  - `Keyword.recommended` returns opportunity >= 70
  - `Keyword.queued_for_generation` returns queued keywords
  - `Keyword.scheduled` returns keywords with scheduled_for set
- ✅ Helper methods work:
  - `easy_win?` returns true when opportunity >= 70
  - `medium_opportunity?` returns true when 50 <= opportunity < 70
  - `difficulty_level` returns "Low", "Medium", or "High"
  - `difficulty_badge_color` returns appropriate emoji
- ✅ Deleting keyword cascades to article

#### Article Model
```ruby
# app/models/article.rb
class Article < ApplicationRecord
  belongs_to :keyword
  belongs_to :project

  enum :status, { pending: 0, generating: 1, completed: 2, failed: 3 }

  validates :keyword_id, uniqueness: true # One article per keyword

  # Fields:
  # - title:string (SEO-optimized title)
  # - meta_description:string (155 chars max)
  # - content:text (full markdown article)
  # - outline:jsonb (structured outline data from generation)
  # - serp_data:jsonb (competitive analysis from SERP research)
  # - status:integer (enum: pending/generating/completed/failed, default: 0)
  # - word_count:integer (actual words in generated content)
  # - target_word_count:integer (target from outline)
  # - generation_cost:decimal(10,4) (AI API cost in USD, e.g. 0.2200)
  # - started_at:datetime (when generation began)
  # - completed_at:datetime (when finished or failed)
  # - error_message:text (populated on failure)

  def retry!
    update!(status: :pending, error_message: nil)
    ArticleGenerationJob.perform_later(id)
  end

  def export_markdown
    content
  end

  def export_html
    require 'kramdown'
    Kramdown::Document.new(content).to_html
  end
end
```

**Specs:**
- ✅ `article.keyword` returns associated keyword
- ✅ `article.project` returns parent project
- ✅ Status enum works: `pending?`, `generating?`, `completed?`, `failed?`
- ✅ Validates uniqueness of `keyword_id` (one article per keyword)
- ✅ `generation_cost` has 4 decimal places for precise tracking
- ✅ `retry!` resets status and error_message, enqueues job
- ✅ `export_markdown` returns content as-is
- ✅ `export_html` converts markdown to HTML using kramdown
- ✅ Can track generation lifecycle: pending → generating → completed
- ✅ Stores both outline and serp_data as JSONB for flexibility

### Database Indexes Created

For performance optimization, these indexes were added:

**keyword_researches:**
- `index_keyword_researches_on_project_id` (from references)
- `index_keyword_researches_on_status` (for filtering by status)

**keywords:**
- `index_keywords_on_keyword_research_id` (from references)
- `index_keywords_on_opportunity` (for sorting by opportunity)
- `index_keywords_on_published` (for filtering published)
- `index_keywords_on_starred` (for filtering favorites)
- `index_keywords_on_queued_for_generation` (for queue management)
- `index_keywords_on_generation_status` (for status filtering)

**articles:**
- `index_articles_on_keyword_id` (UNIQUE, from references)
- `index_articles_on_project_id` (from references)
- `index_articles_on_status` (for filtering by status)

---

## Phase 2: Keyword Research System (Days 4-7) ✅ COMPLETED

### 2.1 Set Up AI Service Infrastructure ✅

```bash
# Create AI service directory
mkdir -p app/services/ai
```

**Create `app/services/ai/client_service.rb`:**
- Unified wrapper around `ruby_llm` gem
- Model configuration (Gemini for analysis, GPT-4o Mini for writing)
- Convenience constructors (`for_keyword_analysis`, `for_outline_generation`, etc.)

**Reference:** See `very_simple_seo_technical_document.md` lines 916-992 for exact implementation.

### 2.2 Port Keyword Research Services ✅

**Create these service files:**

1. **`app/services/google_suggestions_service.rb`** ✅
   - Port logic from `bin/keyword_research` lines 96-110
   - Fetches Google autocomplete suggestions
   - Returns array of keyword strings

2. **`app/services/serp_scraper_service.rb`** ✅
   - Port PAA logic from `bin/keyword_research` lines 112-142
   - Port Related Searches from lines 144-174
   - Uses Nokogiri to scrape Google results

3. **`app/services/reddit_miner_service.rb`** ✅
   - Port Reddit logic from `bin/keyword_research` lines 176-238
   - Fetches Reddit search results via JSON API
   - Extracts keywords from post titles

4. **`app/services/competitor_analysis_service.rb`** ✅
   - Port sitemap scraping from `bin/keyword_research` lines 256-306
   - Port page scraping from lines 308-357
   - Extracts keywords from competitor domains

5. **`app/services/keyword_metrics_service.rb`** ✅
   - Port heuristic metrics from `bin/keyword_research` lines 443-523
   - Estimates volume, difficulty, CPC, intent
   - Falls back when Google Ads API unavailable
   - **BONUS:** Integrated with Google Ads API (optional)

6. **`app/services/seed_keyword_generator.rb`** ✅
   - Uses AI to generate seed keywords from domain + competitors

### 2.3 Create Main Keyword Research Service ✅

**`app/services/keyword_research_service.rb`:**
- Orchestrates all sub-services
- Implements main flow from `bin/keyword_research` lines 40-63
- Saves top 30 keywords to database

**Reference:** See `very_simple_seo_technical_document.md` lines 441-520 for structure.

**Steps:**
1. Generate seed keywords (via `SeedKeywordGenerator`)
2. Expand via Google autocomplete
3. Mine Reddit topics
4. Scrape competitor sitemaps
5. Calculate metrics (volume, difficulty, opportunity)
6. Save top 30 to `Keyword` model

### 2.4 Create Background Job ✅

**`app/jobs/keyword_research_job.rb`:**
- Accepts `keyword_research_id`
- Updates status to `:processing`
- Calls `KeywordResearchService.new(keyword_research).perform`
- Broadcasts status changes via Solid Cable (ready for Phase 4)
- Handles errors gracefully

**Reference:** See `very_simple_seo_technical_document.md` lines 848-867.

**Acceptance:**
- ✅ Can run keyword research in Rails console:
  ```ruby
  project = Project.first
  research = project.keyword_researches.create!(status: :pending)
  KeywordResearchJob.perform_now(research.id)
  research.reload.completed? # => true
  research.keywords.count # => 30
  ```
- ✅ Keywords have proper metrics (volume, difficulty, opportunity)
- ✅ Seeds come from AI analysis
- ✅ Sources tracked (autocomplete, reddit, competitors)

---

## Phase 3: Article Generation System (Days 8-11)

### 3.1 Create SERP Research Service

**`app/services/serp_research_service.rb`:**
- Port Google Custom Search API call from `bin/generate_article` lines 334-386
- Port article scraping from lines 287-332
- Port batch analysis from lines 159-264
- Returns: `{ data: { common_topics:, content_gaps:, detailed_examples:, statistics: }, cost: 0.20 }`

**Key features:**
- Fetches top 10 Google results via Custom Search API
- Scrapes full article content
- Analyzes in batches of 3 (Gemini output limits)
- Extracts real examples and statistics

### 3.2 Create Article Outline Service

**`app/services/article_outline_service.rb`:**
- Port outline generation from `bin/generate_article` lines 388-468
- Uses Gemini 2.5 Flash
- Returns JSON outline with sections, tool placements, word counts

### 3.3 Create Article Writer Service

**`app/services/article_writer_service.rb`:**
- Port section writing from `bin/generate_article` lines 470-603
- Uses GPT-4o Mini for high-quality content
- Writes intro, sections, conclusion
- Maintains voice consistency

### 3.4 Create Article Improvement Service

**`app/services/article_improvement_service.rb`:**
- Port improvement logic from `bin/generate_article` lines 661-711
- Runs 3 passes to fix:
  - Overused companies (max 2x)
  - AI clichés ("delve", "unlock", "harness")
  - Long paragraphs (max 3 sentences)
  - Profanity cleanup

### 3.5 Create Main Article Generation Service

**`app/services/article_generation_service.rb`:**
- Orchestrates all article services
- Tracks costs per step
- Updates article record with SERP data, outline, content

**Flow:**
1. Research SERP → save to `article.serp_data`
2. Generate outline → save to `article.outline`
3. Write article → combine intro + sections + conclusion
4. Add tool placeholders
5. Run 3 improvement passes
6. Save final content + metadata

**Reference:** See `very_simple_seo_technical_document.md` lines 532-633.

### 3.6 Create Background Job

**`app/jobs/article_generation_job.rb`:**
- Accepts `article_id`
- Updates status to `:generating`
- Calls `ArticleGenerationService.new(article).perform`
- Broadcasts status via Solid Cable
- Logs generation cost

**Reference:** See `very_simple_seo_technical_document.md` lines 873-893.

**Acceptance:**
- ✅ Can generate article in Rails console:
  ```ruby
  keyword = Keyword.first
  article = Article.create!(keyword: keyword, project: keyword.project, status: :pending)
  ArticleGenerationJob.perform_now(article.id)
  article.reload.completed? # => true
  article.word_count > 2000 # => true
  article.generation_cost # => ~0.22
  ```
- ✅ Article has SEO title + meta description
- ✅ Content includes real examples from SERP research
- ✅ No AI clichés or profanity

---

## Phase 4: Real-time Updates with Solid Cable (Day 12)

### 4.1 Configure Solid Cable

Solid Cable is already installed by the template. Verify configuration:

```ruby
# config/cable.yml should have:
production:
  adapter: solid_cable

development:
  adapter: solid_cable
```

### 4.2 Create ActionCable Channels

**`app/channels/keyword_research_channel.rb`:**
```ruby
class KeywordResearchChannel < ApplicationCable::Channel
  def subscribed
    keyword_research = KeywordResearch.find(params[:id])
    return reject unless keyword_research.project.user == current_user

    stream_for keyword_research
  end
end
```

**`app/channels/article_channel.rb`:**
```ruby
class ArticleChannel < ApplicationCable::Channel
  def subscribed
    article = Article.find(params[:id])
    return reject unless article.project.user == current_user

    stream_for article
  end
end
```

### 4.3 Add Broadcasting to Jobs

Update jobs to broadcast status changes:

**In `KeywordResearchJob`:**
```ruby
def broadcast_status(keyword_research)
  KeywordResearchChannel.broadcast_to(
    keyword_research,
    {
      id: keyword_research.id,
      status: keyword_research.status,
      total_keywords_found: keyword_research.total_keywords_found
    }
  )
end
```

**In `ArticleGenerationJob`:**
```ruby
def broadcast_status(article)
  ArticleChannel.broadcast_to(
    article,
    {
      id: article.id,
      status: article.status,
      word_count: article.word_count
    }
  )
end
```

**Acceptance:**
- ✅ Channels authorize correctly (reject unauthorized users)
- ✅ Status updates broadcast when jobs run
- ✅ No polling needed (pure push updates)

---

## Phase 5: Controllers & Routes (Days 13-14)

### 5.1 Projects Controller

**`app/controllers/projects_controller.rb`:**
- `index` - List user's projects
- `new` - Create project form
- `create` - Save project, auto-detect competitors, start keyword research
- `show` - View project with keyword opportunities
- `edit` / `update` - Modify project details

**Reference:** See `very_simple_seo_technical_document.md` lines 1036-1087.

### 5.2 Articles Controller

**`app/controllers/articles_controller.rb`:**
- `create` - Start article generation for a keyword
- `show` - View/edit article
- `export` - Download as markdown or HTML

**Reference:** See `very_simple_seo_technical_document.md` lines 1090-1148.

### 5.3 Add Routes

```ruby
# config/routes.rb
resources :projects do
  resources :articles, only: [:create]
end

resources :articles, only: [:show] do
  get :export, on: :member
end
```

**Acceptance:**
- ✅ `/projects` lists all projects
- ✅ `/projects/new` creates project + starts research
- ✅ `/projects/:id` shows keywords for project
- ✅ Can generate article from keyword
- ✅ `/articles/:id` shows article content
- ✅ Can export article as .md or .html

---

## Phase 6: Frontend Pages (Days 15-18) ✅ COMPLETED

**See full summary at `docs/phase6_summary.md`**

### 6.1 Projects Pages ✅

**Created:**
- ✅ `app/frontend/pages/App/Projects/Index.jsx` - List projects
- ✅ `app/frontend/pages/App/Projects/New.jsx` - Create project form
- ✅ `app/frontend/pages/App/Projects/Show.jsx` - Keyword opportunities table with real-time updates
- ✅ `app/frontend/pages/App/Projects/Edit.jsx` - Edit project details

**Key features:**
- Use shadcn/ui `Card`, `Button`, `Input`, `Label`
- Real-time status updates via `createConsumer()` from `@rails/actioncable`
- Show loading state while research runs

**Reference:** See frontend structure in `very_simple_seo_technical_document.md` lines 100-119.

### 6.2 Keyword Table Component

**`app/frontend/components/app/KeywordTable.jsx`:**
- Displays keywords with volume, difficulty, opportunity
- Color-coded opportunity badges (green/yellow/red)
- "Generate Article" button per keyword

**Reference:** See `very_simple_seo_technical_document.md` lines 1154-1214.

### 6.3 Articles Pages

**Create:**
- `app/frontend/pages/App/Articles/Show.jsx` - View/edit article
- `app/frontend/components/app/ArticleEditor.jsx` - Textarea + export buttons

**Key features:**
- Show loading state while generating (subscribe to `ArticleChannel`)
- Textarea for light editing
- Copy to clipboard, download markdown, download HTML

**Reference:** See `very_simple_seo_technical_document.md` lines 1217-1264.

### 6.4 Update Dashboard

**`app/frontend/pages/App/Dashboard.jsx`:**
- Show recent projects
- Quick stats (total keywords found, articles generated)
- CTA to create new project

### 6.5 Add Real-time Subscriptions

**Example for `Projects/Show.jsx`:**
```jsx
import { useEffect, useState } from "react";
import { createConsumer } from "@rails/actioncable";

const [researchStatus, setResearchStatus] = useState(research?.status);

useEffect(() => {
  if (!research || research.status === 'completed') return;

  const cable = createConsumer();
  const subscription = cable.subscriptions.create(
    { channel: "KeywordResearchChannel", id: research.id },
    {
      received(data) {
        setResearchStatus(data.status);
        if (data.status === 'completed') {
          router.reload({ only: ['keywords', 'research'] });
        }
      }
    }
  );

  return () => subscription.unsubscribe();
}, [research?.id]);
```

**Acceptance:**
- ✅ Can create project via form
- ✅ Shows "Researching keywords..." while job runs
- ✅ Automatically updates when research completes (no refresh needed)
- ✅ Can generate article from any keyword
- ✅ Shows "Generating article..." while job runs
- ✅ Can view/edit/export completed articles

---

## Phase 7: Subscription Limits & Billing (Day 19)

### 7.1 Update PlansService

**`app/services/plans_service.rb`:**

Already created by template. Update with VerySimpleSEO-specific limits:

```ruby
PLAN_LIMITS = {
  "free" => {
    max_projects: 1,
    max_articles_per_month: 3
  },
  "pro" => {
    max_projects: 3,
    max_articles_per_month: 15
  },
  "premium" => {
    max_projects: 10,
    max_articles_per_month: 50
  }
}
```

### 7.2 Add Usage Tracking

**Create `app/services/usage_service.rb`:**
- `can_create_project?(user)` - Check against plan limits
- `can_generate_article?(user)` - Check monthly article count
- `articles_generated_this_month(user)` - Count articles

### 7.3 Enforce Limits in Controllers

**In `ProjectsController#create`:**
```ruby
unless UsageService.can_create_project?(Current.user)
  redirect_to projects_path, alert: "Upgrade to create more projects"
  return
end
```

**In `ArticlesController#create`:**
```ruby
unless UsageService.can_generate_article?(Current.user)
  redirect_to pricing_path, alert: "Upgrade to generate more articles"
  return
end
```

**Acceptance:**
- ✅ Free users limited to 1 project, 3 articles/month
- ✅ Pro users get 3 projects, 15 articles/month
- ✅ Premium users get 10 projects, 50 articles/month
- ✅ Clear upgrade prompts when limits hit

---

## Phase 8: Polish & Testing (Days 20-22)

### 8.1 Add Tests

**Controller tests:**
```bash
# Test project CRUD
rails generate test:integration projects_flow

# Test article generation
rails generate test:integration article_generation_flow
```

**Service tests:**
```bash
# Test keyword research
rails test test/services/keyword_research_service_test.rb

# Test article generation
rails test test/services/article_generation_service_test.rb
```

**Key test scenarios:**
- Keyword research completes successfully
- Article generation with real SERP data
- Subscription limits enforced
- Real-time updates broadcast correctly

### 8.2 Add Error Handling

- Failed keyword research → show "Retry" button
- Failed article generation → show error message + cost refund
- Google API quota exceeded → clear error message
- Stripe webhook failures → log + retry

### 8.3 Add SEO Metadata

**Update `app/views/layouts/application.html.erb`:**
- Set proper page titles per route
- Add OG tags for sharing

**Create `config/sitemap.rb`:**
```ruby
add '/pricing', changefreq: 'monthly'
add '/features', changefreq: 'monthly'
# Don't add authenticated routes
```

### 8.4 Performance Optimization

- Add database indexes (already in migrations)
- Eager load associations (`includes(:keywords)`)
- Add pagination to keyword tables if >100 keywords

**Acceptance:**
- ✅ Test suite passes (`rails test`)
- ✅ No N+1 queries (check with Bullet gem)
- ✅ Error states handled gracefully
- ✅ SEO metadata present on public pages

---

## Phase 9: Deployment Documentation (Day 23) ✅ COMPLETED

**Status:** Complete - All deployment documentation created

**See:** `docs/phase9_complete.md` for full summary

### 9.1 Deployment Documentation Created ✅

**Files Created:**
1. **`docs/deployment_guide.md`** (500+ lines)
   - Complete Fly.io walkthrough
   - Alternative providers (Hetzner, DigitalOcean)
   - Kamal configuration explanation
   - PostgreSQL setup
   - Environment variables guide
   - Step-by-step deployment
   - Troubleshooting (10+ common issues)
   - Monitoring commands
   - Cost estimates

2. **`docs/deployment_checklist.md`** (300+ lines)
   - Pre-flight checklist (9 API keys)
   - Server setup options
   - Configuration updates
   - Deployment commands
   - Verification steps
   - Common commands reference

3. **`docs/phase9_complete.md`**
   - Phase 9 summary
   - Architecture overview
   - Performance expectations
   - Success metrics

### 9.2 Kamal Configuration Updated ✅

**Updated:** `config/deploy.yml`
- Added all required environment variables
- Documented all placeholders
- Configured Solid Queue to run in Puma
- Set production defaults
- Added scaling guidance

**Updated:** `.kamal/secrets`
- Documented all 9 API keys
- Added links to credential dashboards
- Security warnings (use production keys!)

### 9.3 Deployment Options Documented ✅

**Option 1: Fly.io** (Recommended for MVP)
- $10/month (app + database)
- Managed PostgreSQL with backups
- Easy scaling
- Global CDN

**Option 2: Hetzner** (Best value)
- €4.5/month (~$5)
- Dedicated resources
- Manual setup required

**Option 3: DigitalOcean**
- $21/month (with managed DB)
- Docker pre-installed
- Great documentation

### 9.4 Quick Start Guide ✅

Ready to deploy in 5 commands:

```bash
# 1. Export secrets (9 required)
export KAMAL_REGISTRY_PASSWORD=...
export OPENAI_API_KEY=...
# ... (see deployment_checklist.md)

# 2. Update config/deploy.yml
# - Docker Hub username
# - Server IP
# - Domain

# 3. Deploy
kamal setup

# 4. Run migrations
kamal app exec "bin/rails db:migrate"
kamal app exec "bin/rails runner db/seeds/pay_plans.rb"

# 5. Verify
kamal app logs -f
```

### 9.5 Troubleshooting Guide ✅

**Common issues documented:**
- Docker build failures → Solution: Start Docker Desktop
- Solid Queue not processing → Solution: Check SOLID_QUEUE_IN_PUMA=true
- Out of memory → Solution: Upgrade to 2GB RAM or add swap
- Database connection failed → Solution: Verify DATABASE_URL
- Stripe webhooks not working → Solution: Check webhook configuration

**Acceptance:**
- ✅ Complete deployment guides created
- ✅ Pre-flight checklist with API keys
- ✅ Kamal configuration documented
- ✅ 3 hosting options compared
- ✅ Troubleshooting guide (10+ issues)
- ✅ Monitoring commands documented
- ✅ Security checklist included
- ✅ Cost estimates provided

**Next:** Follow `docs/deployment_checklist.md` to deploy to production!

---

## Phase 10: Beta Launch (Days 24-28)

### 10.1 Create Marketing Homepage

**Update `app/frontend/pages/Home.jsx`:**
- Hero: "Find winning keywords and generate SEO articles in minutes"
- Features: Keyword research, AI article generation, No tools needed
- Pricing CTA
- FAQ section

### 10.2 Update Pricing Page

**Already exists from template:**
- Show 3 plans (Free, Pro $19/mo, Premium $49/mo)
- List features per plan
- CTA to sign up

### 10.3 Beta User Outreach

**Target:**
- 10 indie hackers
- 10 SaaS founders
- 10 content creators

**Channels:**
- Indie Hackers
- Twitter
- Reddit (r/SaaS, r/EntrepreneurRideAlong)

### 10.4 Collect Feedback

**Add to article generation:**
- Simple thumbs up/down rating
- Optional feedback textarea
- Track ratings in database

**Acceptance:**
- ✅ 10 beta users signed up
- ✅ At least 5 users generated articles
- ✅ Collect feedback on keyword quality
- ✅ Collect feedback on article quality

---

## Success Metrics (First 30 Days)

- **Signups:** 50 total users
- **Paid conversions:** 5 paying customers (10% conversion)
- **Articles generated:** 100+ articles
- **Keyword researches:** 30+ projects
- **User satisfaction:** 80%+ positive feedback
- **Technical reliability:** <1% job failure rate

---

## Post-MVP Features (V2)

After successful MVP launch, consider:

1. **Bulk article generation** - Queue 10 articles at once
2. **Content calendar** - Schedule articles for future generation
3. **WordPress integration** - Direct publish to WordPress
4. **Team collaboration** - Share projects with team members
5. **Voice training** - Upload writing samples for tone matching
6. **Rank tracking** - Monitor keyword rankings over time
7. **Content refresh** - Re-optimize old articles

---

## Key Files to Port

From `ai-validator` codebase, you'll need to port:

### From `bin/keyword_research`:
- ✅ Google autocomplete logic (lines 96-110)
- ✅ People Also Ask scraping (lines 112-142)
- ✅ Related Searches scraping (lines 144-174)
- ✅ Reddit mining (lines 176-238)
- ✅ Competitor sitemap scraping (lines 256-306)
- ✅ Competitor page scraping (lines 308-357)
- ✅ Keyword metrics heuristics (lines 443-523)

### From `bin/generate_article`:
- ✅ Google Custom Search API (lines 334-386)
- ✅ Article content scraping (lines 287-332)
- ✅ Batch SERP analysis (lines 159-264)
- ✅ Outline generation (lines 388-468)
- ✅ Section writing (lines 470-603)
- ✅ Article improvement (lines 661-711)

### From `bin/lib/seed_keyword_generator.rb`:
- ✅ Copy entire file to `app/services/`

### From `bin/lib/google_ads_service.rb`:
- ⚠️ Optional - only if you want real Google Ads metrics
- Falls back to heuristics if not configured

---

## Cost Estimates

**Per article generation:**
- SERP Research (Gemini 2.5 Flash): $0.01
- Outline Generation (Gemini 2.5 Flash): $0.01
- Article Writing (GPT-4o Mini): $0.15
- Improvements (GPT-4o Mini × 3): $0.05
- **Total:** ~$0.22 per article

**Monthly costs at scale:**
- 100 articles/month = $22 in AI costs
- Pro plan ($19/mo, 15 articles) = $3.30 AI cost → **82% margin**
- Premium plan ($49/mo, 50 articles) = $11 AI cost → **78% margin**

Excellent margins even with aggressive pricing!

---

## Next Steps

1. Run Phase 0 to generate the Rails app
2. Complete Phases 1-2 (models + keyword research) in first week
3. Complete Phases 3-4 (article generation + real-time) in second week
4. Complete Phases 5-6 (controllers + frontend) in third week
5. Polish, test, deploy (Phase 7-9) in fourth week
6. Beta launch (Phase 10) and iterate

You're building a real, profitable SaaS with high margins and clear value prop. Ship it! 🚀
