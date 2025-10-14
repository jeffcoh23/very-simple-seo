# Keyword Research Flow

## Overview

The keyword research system automatically discovers and analyzes SEO keyword opportunities for a project. It combines multiple data sources, calculates competitive metrics, and identifies the best content opportunities.

**Entry Point:** When a project is created, `KeywordResearchJob` is automatically enqueued.

**Duration:** ~40 seconds

**Output:** Top 30 keyword opportunities ranked by opportunity score

---

## Architecture

```
ProjectsController#create
  └─> KeywordResearchJob (background)
      └─> KeywordResearchService
          ├─> Generate seeds
          ├─> Expand keywords
          ├─> Mine Reddit
          ├─> Analyze competitors
          ├─> Calculate metrics
          └─> Save top 30 keywords
```

---

## Detailed Flow

### 1. Generate Seed Keywords

**Location:** `app/services/keyword_research_service.rb:43`

**Purpose:** Create initial keyword list from project data

**Sources:**
- User-provided seed keywords (from project form)
- OR generated from domain content via `SeedKeywordGenerator`
- Project domain analysis (H1s, H2s, meta tags)
- Competitor domains

**Output:** 15-20 seed keywords stored in `keyword_research.seed_keywords`

**Example:**
```ruby
# User provided:
["business idea validation", "startup validation", "validate startup idea"]

# OR AI-generated from domain:
["idea validator tool", "startup idea testing", "market validation"]
```

---

### 2. Expand Keywords

**Location:** `app/services/keyword_research_service.rb:65`

**Purpose:** Find related keywords and variations

**Methods:**

#### a) Google Autocomplete (`GoogleSuggestionsService`)
- For each seed keyword, fetch autocomplete suggestions
- E.g., "business idea validation" → "business idea validation tool", "business idea validation checklist"
- ~10 suggestions per seed

#### b) People Also Ask (`SerpScraperService`)
- Scrapes PAA questions from Google SERP
- Extracts question-based keywords
- E.g., "how to validate a business idea", "what is idea validation"

#### c) Related Searches (`SerpScraperService`)
- Scrapes "Related searches" section at bottom of Google results
- Finds semantically related keywords
- E.g., "startup validation framework", "product market fit"

**Rate Limiting:** 2-second delay between each seed expansion

**Output:** 100-300 total keywords after expansion

---

### 3. Mine Reddit

**Location:** `app/services/keyword_research_service.rb:89`

**Purpose:** Discover real user language and long-tail keywords

**Process:**
1. Takes first 5 seed keywords
2. Searches Reddit via `RedditMinerService`
3. Extracts keywords from:
   - Post titles
   - Popular comments
   - Subreddit names

**Why Reddit:**
- Real user questions and pain points
- Natural language variations
- Long-tail, low-competition keywords
- Uncovers content gaps

**Rate Limiting:** 2-second delay between searches

**Output:** +20-50 keywords from discussions

---

### 4. Analyze Competitors

**Location:** `app/services/keyword_research_service.rb:104`

**Purpose:** Find keywords competitors are ranking for

**Process:**
1. For each competitor domain (from project)
2. Scrape sitemap and pages via `CompetitorAnalysisService`
3. Extract:
   - Page titles
   - H1 headings
   - Meta keywords
   - URL slugs

**Example:**
- Competitor: `validatorai.com`
- Extracted keywords: "AI validator", "startup validation AI", "automated idea testing"

**Output:** +30-100 keywords from competitors

**Skip if:** No competitors added to project

---

### 5. Calculate Metrics

**Location:** `app/services/keyword_research_service.rb:119`

**Purpose:** Score each keyword with SEO metrics

**Two Methods:**

#### a) Google Ads API (if configured)
- **Requires:** `GOOGLE_ADS_DEVELOPER_TOKEN` environment variable
- **Batch fetches** real data for all keywords at once
- **Accurate metrics:**
  - Search Volume (monthly searches)
  - CPC (cost per click)
  - Competition level

#### b) Heuristic Fallback (default)
- **Uses:** `KeywordMetricsService`
- **Estimates based on:**
  - Keyword length (shorter = higher volume, harder)
  - Word count (long-tail = lower volume, easier)
  - Commercial intent keywords (e.g., "buy", "tool", "software")
  - Question keywords (e.g., "how to", "what is")

**Calculated Metrics:**
- **Volume:** Monthly search volume (0-100,000+)
- **Difficulty:** Competition score (0-100, lower = easier to rank)
- **CPC:** Cost per click in USD ($0.00 - $50.00+)
- **Intent:** Informational, Commercial, Transactional, Navigational
- **Opportunity Score:** Calculated as `(volume / 100) * (100 - difficulty)`
  - Higher score = high volume + low difficulty = best target

**Example Metrics:**
```ruby
{
  keyword: "business idea validation",
  volume: 1200,
  difficulty: 45,
  cpc: 3.25,
  intent: "commercial",
  opportunity: 660  # (1200/100) * (100-45)
}
```

---

### 6. Save Top Keywords

**Location:** `app/services/keyword_research_service.rb:179`

**Purpose:** Store best opportunities in database

**Process:**
1. Sort all keywords by **opportunity score** (highest first)
2. Take top 30 keywords
3. Save to `keywords` table with:
   - All metrics
   - Sources (where keyword was found)
   - Link to project

**Why only 30?**
- Focus on best opportunities
- Avoid overwhelming the user
- Reduce database bloat
- All keywords are still tracked in-memory during research

**Result:** User sees top 30 keywords on project show page

---

## Real-Time Progress Updates

**Uses:** ActionCable via `KeywordResearchChannel`

**Location:** `app/jobs/keyword_research_job.rb:105`

**What's broadcast:**
- Current step (with emoji indicators)
- Progress messages
- Keywords found so far
- Completion status

**Frontend:** `app/frontend/pages/App/Projects/Show.jsx:22-71`
- Subscribes to channel
- Updates UI in real-time
- Shows progress log
- Reloads page when complete

**Example Progress Log:**
```
🌱 Generating seed keywords from your domain...
  → business idea validation
  → startup validation
  ... and 13 more
✅ Generated 15 seed keywords

🔍 Expanding keywords via Google autocomplete...
  → Expanding: business idea validation
  ... expanding 14 more seeds
✅ Found 287 total keywords after expansion

📱 Mining Reddit for topic ideas...
✅ Mined Reddit discussions

🔎 Analyzing 5 competitors...
  → Scraping: https://validatorai.com
  → Scraping: https://founderpal.ai
✅ Scraped competitor content

📊 Calculating metrics for 342 keywords...
  → Using heuristic estimates
✅ Metrics calculated (volume, difficulty, CPC, opportunity)

💾 Saving top 30 keywords...
🎉 Research complete! Found 30 opportunities
```

---

## Database Schema

### `keyword_researches` table
```ruby
t.bigint "project_id", null: false
t.string "status"           # pending, processing, completed, failed
t.jsonb "seed_keywords"     # Array of initial seeds
t.jsonb "progress_log"      # Array of progress messages
t.integer "total_keywords_found"
t.datetime "started_at"
t.datetime "completed_at"
t.text "error_message"
```

### `keywords` table
```ruby
t.bigint "project_id", null: false
t.bigint "keyword_research_id"
t.string "keyword"
t.integer "volume"           # Monthly searches
t.integer "difficulty"       # 0-100 competition score
t.decimal "cpc"              # Cost per click
t.integer "opportunity"      # Calculated score
t.string "intent"            # informational, commercial, transactional, navigational
t.jsonb "sources"            # ["seed", "autocomplete", "reddit"]
t.boolean "starred"
t.boolean "published"
```

---

## Error Handling

### Job Failures
If `KeywordResearchJob` fails:
1. Status set to `failed`
2. Error message stored in `error_message` column
3. User sees error banner on project page
4. Partial results are NOT saved (atomic operation)

### Service Failures
- **Google API rate limit:** Falls back to next seed
- **Reddit timeout:** Logs warning, continues to next step
- **Competitor scrape fails:** Logs error, continues with other competitors
- **Metrics calculation fails:** Uses fallback heuristics

---

## Performance & Costs

### Duration
- **Typical:** 30-40 seconds
- **With competitors (5):** 45-60 seconds
- **Without Reddit mining:** 20-30 seconds

### API Calls
- Google autocomplete: ~15 requests (1 per seed)
- SERP scraping: ~15 requests (1 per seed)
- Reddit API: ~5 requests
- Competitor scraping: N requests (N = number of competitors)
- Google Ads API (optional): 1 batch request for all keywords

### Costs
- **Without Google Ads API:** $0 (all free APIs with rate limiting)
- **With Google Ads API:** ~$0.001 per keyword (batch optimization)

---

## Configuration

### Environment Variables

```bash
# Optional: For accurate keyword metrics
GOOGLE_ADS_DEVELOPER_TOKEN=your_token_here
GOOGLE_ADS_CLIENT_ID=your_client_id
GOOGLE_ADS_CLIENT_SECRET=your_secret
GOOGLE_ADS_REFRESH_TOKEN=your_refresh_token

# Required: For SERP scraping (in SerpScraperService)
GOOGLE_SEARCH_KEY=your_google_api_key
GOOGLE_SEARCH_CX=your_custom_search_engine_id
```

### Customization

To adjust the number of keywords saved:
```ruby
# app/services/keyword_research_service.rb:186
top_30 = sorted.first(30)  # Change 30 to desired number
```

To change Reddit seed limit:
```ruby
# app/services/keyword_research_service.rb:92
@keyword_research.seed_keywords.first(5)  # Change 5 to desired number
```

---

## Related Files

### Core Services
- `app/services/keyword_research_service.rb` - Main orchestration
- `app/services/seed_keyword_generator.rb` - Generates seeds from domain
- `app/services/google_suggestions_service.rb` - Autocomplete API
- `app/services/serp_scraper_service.rb` - PAA + Related searches
- `app/services/reddit_miner_service.rb` - Reddit keyword mining
- `app/services/competitor_analysis_service.rb` - Competitor scraping
- `app/services/keyword_metrics_service.rb` - Metrics calculation

### Jobs & Channels
- `app/jobs/keyword_research_job.rb` - Background processing
- `app/channels/keyword_research_channel.rb` - Real-time updates

### Models
- `app/models/keyword_research.rb` - Research record
- `app/models/keyword.rb` - Individual keywords

### Controllers
- `app/controllers/projects_controller.rb:39` - Enqueues job on create

### Frontend
- `app/frontend/pages/App/Projects/Show.jsx` - Real-time progress display
