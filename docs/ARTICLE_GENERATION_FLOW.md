# Article Generation Flow

## Overview

The article generation system creates high-quality, SEO-optimized content by analyzing top-ranking competitors and using AI to write comprehensive articles that can outrank them.

**Entry Point:** User clicks "Generate" button next to a keyword on the project show page.

**Duration:** 2-4 minutes (depending on target word count)

**Cost:** $0.15 - $0.25 per article (with GPT-4o Mini)

**Output:** Complete article with title, meta description, markdown content, examples, and statistics

---

## Architecture

```
ArticlesController#create
  └─> ArticleGenerationJob (background)
      └─> 4-Step Pipeline:
          1. SERP Research (SerpResearchService)
          2. Generate Outline (ArticleOutlineService)
          3. Write Article (ArticleWriterService)
          4. Improve Article (ArticleImprovementService)
```

---

## Detailed Flow

### Step 1: SERP Research

**Duration:** 30-60 seconds

**Cost:** $0.20 (Gemini Pro batch analysis)

**Location:** `app/services/serp_research_service.rb`

**Purpose:** Analyze top 10 Google results to understand what content ranks well

**Process:**

#### 1a. Fetch Search Results
- Uses Google Custom Search API
- Fetches top 10 organic results for the target keyword
- Extracts title, URL, snippet for each result

**Example:**
```ruby
# Keyword: "business idea validation"
results = [
  { title: "How to Validate Your Business Idea in 2024",
    url: "https://example.com/validate-idea" },
  { title: "5 Steps to Validate Any Startup Idea",
    url: "https://competitor.com/validation" },
  # ... 8 more
]
```

#### 1b. Scrape Article Content
- For each of the 10 URLs, fetch the full HTML
- Extract main content using Nokogiri:
  - Looks for `<article>`, `<main>`, or `[role="main"]`
  - Removes scripts, styles, nav, footer, headers
  - Extracts plain text
- Calculate word count for each article

**Example:**
```ruby
{
  url: "https://example.com/validate-idea",
  title: "How to Validate Your Business Idea",
  content: "Starting a business without validation is risky...",
  word_count: 2847
}
```

#### 1c. Extract Examples & Statistics (Batch Processing)
- **Why batch?** Gemini has output token limits (~8000 tokens)
- Articles processed in batches of 3
- For each batch, AI extracts:

**Examples:**
```json
{
  "company": "Dropbox",
  "what_they_did": "created demo video before building product",
  "outcome": "75,000 signups overnight",
  "relevance": "MVP validation strategy"
}
```

**Statistics:**
```json
{
  "stat": "42% of startups fail due to no market need",
  "source": "CB Insights",
  "context": "importance of validation"
}
```

**Why extract these?**
- Makes articles more credible and specific
- Provides concrete examples users can reference
- Adds data-driven insights

#### 1d. Analyze Common Topics & Gaps
- AI analyzes all 10 result titles and snippets
- Identifies common topics across multiple articles
- Finds content gaps (topics NOT covered by competitors)
- Calculates average word count
- Recommends approach to beat competitors

**Output:**
```json
{
  "common_topics": [
    "customer interviews and surveys",
    "MVP testing strategies",
    "landing page validation",
    "competitor analysis"
  ],
  "content_gaps": [
    "specific validation tools comparison",
    "validation timeline frameworks",
    "budget considerations"
  ],
  "average_word_count": 2340,
  "recommended_approach": "Create comprehensive guide covering common topics plus gaps, with real examples and data. Target 2500+ words to be competitive."
}
```

**Stored in:** `articles.serp_data` (JSONB column)

---

### Step 2: Generate Outline

**Duration:** 10-15 seconds

**Cost:** $0.02 (GPT-4o Mini)

**Location:** `app/services/article_outline_service.rb`

**Purpose:** Create structured article outline before writing

**Input:**
- Target keyword
- SERP research data (topics, gaps, examples, stats)
- Target word count (user-specified: 1000-3000 words)
- Project call-to-actions (from project settings)

**AI Prompt Includes:**
```
Target keyword: "business idea validation"
Target word count: 2000

SERP Intelligence:
- Common topics in top 10: [list]
- Content gaps to fill: [list]
- Average competitor word count: 2340
- Examples available: [list of 15+ examples]
- Statistics available: [list of 10+ stats]

Project CTAs:
- Try it free: https://example.com/signup

Generate a comprehensive outline that:
1. Covers all common topics (table stakes)
2. Fills content gaps (differentiation)
3. Integrates specific examples and statistics
4. Targets 2000 words
5. Includes natural CTA placements
```

**Output Structure:**
```json
{
  "title": "Complete Guide to Business Idea Validation in 2024",
  "meta_description": "Learn how to validate your business idea with proven strategies, real examples, and expert insights. Avoid the #1 reason startups fail.",
  "sections": [
    {
      "heading": "Why Validation Matters (And the Cost of Skipping It)",
      "target_word_count": 200,
      "key_points": [
        "42% startup failure stat from CB Insights",
        "Real cost examples",
        "Validation vs. assumption"
      ],
      "examples_to_use": ["Dropbox demo video story"],
      "stats_to_use": ["CB Insights failure rate"]
    },
    {
      "heading": "Customer Interview Framework",
      "target_word_count": 400,
      "key_points": [
        "How to find interviewees",
        "Questions to ask",
        "Red flags to watch for"
      ],
      "examples_to_use": ["Airbnb founder interviews"],
      "stats_to_use": []
    },
    // ... more sections
  ],
  "cta_placement": {
    "after_section": 2,
    "cta_text": "Try it free",
    "cta_url": "https://example.com/signup"
  }
}
```

**Key Features:**
- **Word count distribution:** Each section gets a target word count to hit overall target
- **Example mapping:** Specific examples assigned to relevant sections
- **Stat mapping:** Statistics placed where they add most value
- **CTA strategy:** Natural placement (usually after introduction or mid-article)

**Stored in:** `articles.outline` (JSONB column)

---

### Step 3: Write Article

**Duration:** 60-90 seconds

**Cost:** $0.08-0.12 (GPT-4o Mini, varies by length)

**Location:** `app/services/article_writer_service.rb`

**Purpose:** Write complete article following the outline

**Process:**
- **Section-by-section writing:** Each section written separately (better focus)
- **Context provided:** Outline + SERP data + examples/stats for that section
- **Voice profile applied:** User's writing style preferences (from `users.voice_profile`)

**Voice Profile Example:**
```json
{
  "tone": "professional but friendly",
  "style": "concise, actionable",
  "perspective": "first person plural (we)",
  "avoid": ["jargon", "hype"]
}
```

**AI Prompt Per Section:**
```
Write the section: "Customer Interview Framework"

Target word count: 400 words

Key points to cover:
- How to find interviewees
- Questions to ask
- Red flags to watch for

Use this example:
- Airbnb founders: cold-called hosts, learned about photo quality importance

Voice profile:
- Tone: professional but friendly
- Style: concise, actionable

Write in markdown format. Use proper headings, lists, and formatting.
```

**Output:** Complete markdown article with:
- H1 title
- H2 section headings
- H3 subheadings
- Bullet lists
- Bold text for emphasis
- Code blocks (if technical content)
- CTAs integrated naturally

**Stored in:** `articles.content` (text column, markdown format)

---

### Step 4: Improve Article

**Duration:** 45-60 seconds

**Cost:** $0.03-0.05 (GPT-4o Mini, 3 improvement passes)

**Location:** `app/services/article_improvement_service.rb`

**Purpose:** Refine the article for quality and SEO

**3 Improvement Passes:**

#### Pass 1: Content Quality
- Add transitions between sections
- Ensure logical flow
- Expand thin sections
- Add more specific details
- Integrate examples more naturally

#### Pass 2: SEO Optimization
- Ensure keyword appears in:
  - Title
  - First paragraph
  - H2 headings (naturally)
  - Throughout content
- Add semantic variations
- Optimize for featured snippets (lists, tables, definitions)

#### Pass 3: Readability & Polish
- Shorten long sentences
- Break up long paragraphs
- Add subheadings for scannability
- Ensure consistent tone
- Fix any repetition

**AI Prompt Example (Pass 1):**
```
Improve this article for content quality:

SERP Context (what ranks well):
- Common topics: [list]
- Content gaps: [list]
- Examples available: [list]

Current article:
[markdown content]

Improvements needed:
1. Add smooth transitions between sections
2. Expand any thin sections to target word count
3. Integrate examples more naturally
4. Add specific, actionable details
5. Ensure logical flow from intro to conclusion

Return the improved markdown.
```

**Output:** Polished, SEO-optimized markdown article

---

## Final Article Structure

**Complete article includes:**

```markdown
# Complete Guide to Business Idea Validation in 2024

Starting a business without validation is like building a house...

## Why Validation Matters (And the Cost of Skipping It)

According to CB Insights, 42% of startups fail due to no market need...

## Customer Interview Framework

### Finding the Right People to Interview

The most valuable interviews come from...

### Essential Questions to Ask

1. **Problem exploration**: "Tell me about the last time you..."
2. **Solution validation**: "How do you currently solve this?"

[Continue with all sections from outline]

## Conclusion

Validation isn't optional—it's the foundation...

[CTA: Try our validation tool free →]
```

**Stored Fields:**
- `title` - H1 from outline
- `meta_description` - SEO description from outline
- `content` - Full markdown article
- `word_count` - Calculated from final content
- `serp_data` - JSON of SERP research
- `outline` - JSON of article structure
- `generation_cost` - Total AI API cost
- `status` - completed
- `completed_at` - Timestamp

---

## Real-Time Progress Updates

**Uses:** ActionCable via `ArticleChannel`

**Location:** `app/jobs/article_generation_job.rb:147`

**What's broadcast:**
- Current step with emoji indicators
- Word count progress
- Cost accumulation
- Status updates

**Frontend:** `app/frontend/pages/App/Articles/Show.jsx`
- Subscribes to channel when status is "generating"
- Updates progress bar
- Shows live word count
- Displays cost in real-time
- Auto-reloads when complete

**Example Progress Messages:**
```
Starting article generation...
🔍 Researching top 10 Google results...
✅ Found 8 common topics from competitors
📝 Generating article outline with AI...
✅ Outline created (targeting 2000 words)
✍️ Writing article sections with GPT-4o Mini...
✅ Draft complete (2143 words)
✨ Improving article quality (3 passes)...
🎉 Article complete! 2285 words • $0.22 • 187s
```

---

## Database Schema

### `articles` table
```ruby
t.bigint "project_id", null: false
t.bigint "keyword_id", null: false
t.string "status"              # pending, generating, completed, failed
t.string "title"               # Generated title
t.text "meta_description"     # SEO meta description
t.text "content"               # Markdown content
t.integer "word_count"         # Final word count
t.integer "target_word_count"  # User-specified target (1000-3000)
t.jsonb "serp_data"            # SERP research results
t.jsonb "outline"              # Article structure
t.decimal "generation_cost"    # AI API cost in USD
t.datetime "started_at"
t.datetime "completed_at"
t.text "error_message"
```

---

## Error Handling

### Job Failures
If `ArticleGenerationJob` fails at any step:
1. Article status set to `failed`
2. Error message stored in `error_message` column
3. Partial cost tracked (shows how much was spent before failure)
4. User can retry generation (new article record created)

### Step-Specific Failures

**SERP Research fails:**
- Error: "SERP research failed"
- Cause: Google API limit, network timeout
- Cost: $0 (no AI calls made yet)

**Outline generation fails:**
- Error: "Outline generation failed"
- Cause: AI API error, malformed response
- Cost: ~$0.20 (SERP research completed)

**Writing fails:**
- Error: "Article writing failed"
- Cause: AI API error, timeout, content policy violation
- Cost: ~$0.22 (SERP + outline completed)

**Improvement fails:**
- Error: "Article improvement failed"
- Cause: AI API error
- Cost: ~$0.30 (article written, improvements failed)
- **Fallback:** Raw article still available (not improved)

---

## Performance & Costs

### Duration Breakdown
- **SERP Research:** 30-60s (scraping 10 articles)
- **Outline Generation:** 10-15s (single AI call)
- **Article Writing:** 60-90s (section-by-section)
- **Article Improvement:** 45-60s (3 passes)
- **Total:** 2-4 minutes

### Cost Breakdown (GPT-4o Mini)
- **SERP Research (Gemini Pro):** ~$0.20
- **Outline Generation:** ~$0.02
- **Article Writing:** ~$0.08-0.12 (varies by length)
- **Article Improvement:** ~$0.03-0.05 (3 passes)
- **Total:** ~$0.15-0.25 per article

### Scaling Costs
- **1,000 words:** ~$0.15
- **2,000 words:** ~$0.22
- **3,000 words:** ~$0.30

---

## Configuration

### Environment Variables

```bash
# Required: For SERP research
GOOGLE_SEARCH_KEY=your_google_api_key
GOOGLE_SEARCH_CX=your_custom_search_engine_id

# Required: For AI content generation
OPENAI_API_KEY=your_openai_key
ANTHROPIC_API_KEY=your_anthropic_key  # Alternative to OpenAI
GOOGLE_AI_API_KEY=your_gemini_key     # For SERP analysis
```

### AI Model Configuration

**Located in:** `app/services/ai/client_service.rb`

**Default models:**
- **SERP Analysis:** Gemini Pro (cost-effective for batch processing)
- **Outline Generation:** GPT-4o Mini (structured output)
- **Article Writing:** GPT-4o Mini (long-form content)
- **Article Improvement:** GPT-4o Mini (editing)

**To change models:**
```ruby
# In article_writer_service.rb
client = Ai::ClientService.for_article_writing
# Uses: GPT-4o Mini by default

# To use Claude Sonnet instead:
client = Anthropic::Client.new
```

### Customization

**Target word count range:**
```ruby
# app/models/article.rb
validates :target_word_count, inclusion: { in: 1000..3000 }
```

**Number of improvement passes:**
```ruby
# app/services/article_improvement_service.rb
IMPROVEMENT_PASSES = 3  # Change to adjust quality vs. cost
```

**SERP results to analyze:**
```ruby
# app/services/serp_research_service.rb:24
top_articles = fetch_article_content(search_results.take(10))
# Change 10 to adjust depth vs. speed
```

---

## Related Files

### Core Services
- `app/services/serp_research_service.rb` - SERP analysis
- `app/services/article_outline_service.rb` - Outline generation
- `app/services/article_writer_service.rb` - Content writing
- `app/services/article_improvement_service.rb` - Quality refinement
- `app/services/ai/client_service.rb` - AI model abstraction

### Alternative Flow (Synchronous)
- `app/services/article_generation_service.rb` - Synchronous orchestration
- Used for testing/development
- Same 4-step pipeline, no background job

### Jobs & Channels
- `app/jobs/article_generation_job.rb` - Background processing
- `app/channels/article_channel.rb` - Real-time updates

### Models
- `app/models/article.rb` - Article record
- `app/models/keyword.rb` - Associated keyword

### Controllers
- `app/controllers/articles_controller.rb:14` - Creates article & enqueues job
- `app/controllers/articles_controller.rb:44` - Shows article with real-time updates
- `app/controllers/articles_controller.rb:90` - Exports markdown/HTML

### Frontend
- `app/frontend/pages/App/Articles/Show.jsx` - Article display & editing
- `app/frontend/components/app/ArticleGenerateForm.jsx` - Generation trigger

---

## Advanced Features

### Voice Profile Customization

**Location:** User settings (not yet fully implemented in UI)

**Purpose:** Customize AI writing style per user

**Example profile:**
```json
{
  "tone": "professional but friendly",
  "style": "concise, actionable",
  "perspective": "first person plural",
  "sentence_length": "medium",
  "paragraph_length": "short",
  "use_examples": true,
  "use_statistics": true,
  "use_humor": false,
  "avoid": ["jargon", "hype", "passive voice"]
}
```

**Applied in:** `ArticleWriterService` (Step 3)

### CTA Integration

**Source:** Project call-to-actions (`projects.call_to_actions` JSONB)

**Example:**
```json
{
  "text": "Try our validator free",
  "url": "https://example.com/signup"
}
```

**Placement:** AI decides natural placement (usually after intro or mid-article)

**Rendered as:**
```markdown
[Try our validator free →](https://example.com/signup)
```

### Example & Statistic Extraction

**Purpose:** Make articles credible and specific

**Sources:** Top 10 SERP results

**Extraction:** AI-powered parsing in batches

**Storage:** Within `serp_data` JSONB:
```json
{
  "detailed_examples": [...],
  "statistics": [...],
  "common_topics": [...],
  "content_gaps": [...]
}
```

**Usage:** Mapped to outline sections, then referenced during writing

---

## Comparison: Keyword Research vs. Article Generation

| Aspect | Keyword Research | Article Generation |
|--------|------------------|-------------------|
| **Trigger** | Automatic (on project create) | Manual (user clicks Generate) |
| **Duration** | 30-40 seconds | 2-4 minutes |
| **Cost** | $0 (free APIs) | $0.15-0.25 per article |
| **Output** | 30 keyword opportunities | 1 complete article |
| **AI Usage** | Minimal (seed generation only) | Heavy (4-step pipeline) |
| **Batching** | N/A | 3 articles per SERP batch |
| **Real-time** | Yes (ActionCable) | Yes (ActionCable) |
| **Credits** | No | Yes (1 credit per article) |

---

## Future Improvements

### Potential Enhancements
1. **Multi-language support** - Generate articles in any language
2. **Image integration** - AI-generated images for sections
3. **Internal linking** - Automatically link to other articles
4. **Schema markup** - Auto-generate FAQ/HowTo schema
5. **Readability scoring** - Real-time Flesch-Kincaid analysis
6. **Plagiarism check** - Ensure originality before completion
7. **A/B testing** - Generate multiple versions, test performance
8. **Collaborative editing** - Real-time multi-user editing
9. **Publishing integration** - Direct publish to WordPress, Ghost, etc.
10. **Performance tracking** - Monitor rankings, traffic, conversions per article
