# Current Data Usage from Project

## What Data is Currently Being Used?

### ✅ ALREADY IMPLEMENTED (Before Phase 1):

**1. Internal Link Suggester** (`app/services/internal_link_suggester.rb`)
- ✅ **Scrapes existing articles**: Pulls up to 50 completed articles from the same project
- ✅ **Extracts metadata**: Title, keyword, URL, meta description, word count, topics (H2 headings)
- ✅ **Provides to Grounding API**: Feeds article data to SerpGroundingResearchService
- ✅ **Suggests internal links**: AI uses this to recommend 3-5 internal link opportunities
- ✅ **CTA context**: Infers CTA purpose (signup, demo, pricing, trial, etc.)

**Data collected:**
```ruby
{
  'existing_articles' => [
    {
      'title' => "How to Validate Business Ideas",
      'keyword' => "business idea validation",
      'url' => "/articles/123",
      'meta_description' => "Learn to validate...",
      'word_count' => 2500,
      'topics' => ["Understanding Validation", "Customer Interviews", "Landing Pages"]
    }
  ],
  'ctas' => [
    {
      'text' => "Try SignalLab Free",
      'url' => "https://signallab.app/signup",
      'context' => "free_trial"
    }
  ]
}
```

**Where it's used:**
- `SerpGroundingResearchService.perform` → calls `InternalLinkSuggester`
- Passes to Grounding API in "Content Elements" call
- AI suggests internal links based on existing content

---

### ✅ NEW IN PHASE 1 (Just Implemented):

**2. Project Brand Context**
- ✅ **Project name**: Used for brand mentions
- ✅ **Project domain**: Used for CTAs and brand positioning
- ✅ **Project CTAs**: Real CTAs from `project.call_to_actions` JSONB column

**Data used:**
```ruby
@project.name           # "SignalLab"
@project.domain         # "https://signallab.app"
@project.call_to_actions # [
  {
    "cta_text" => "Try SignalLab Free",
    "cta_url" => "https://signallab.app/signup",
    "placement" => "after_intro"
  }
]
```

**Where it's used:**
- `ArticleOutlineService`: Brand positioning + CTA planning
- `ArticleWriterService`: Natural brand mentions in intro/sections/conclusion
- `ArticleImprovementService`: Verifies brand integration (Pass 6)

---

### ❌ NOT YET SCRAPING:

**What we're NOT doing (yet):**
- ❌ **Sitemap scraping**: Not fetching all site URLs from sitemap.xml
- ❌ **Pricing page content**: Not extracting pricing details
- ❌ **Feature pages**: Not scraping product feature descriptions
- ❌ **Blog/resource URLs**: Only uses completed articles in DB, not external pages
- ❌ **External backlinks**: Not analyzing link opportunities
- ❌ **Competitor content**: Not scraping competitor sites (only SERP research)

---

## Data Flow Diagram

```
PROJECT DATA COLLECTION:
┌─────────────────────────────────────────┐
│ Project Model                           │
│ - name: "SignalLab"                    │
│ - domain: "signallab.app"              │
│ - call_to_actions: [{...}]            │
│ - articles: [Article, Article, ...]    │
└─────────────────────────────────────────┘
              │
              ├──> InternalLinkSuggester
              │    │
              │    ├──> Gather existing articles (up to 50)
              │    ├──> Extract topics from H2 headings
              │    ├──> Infer CTA context
              │    └──> Build linking guidelines
              │
              └──> ArticleGenerationService
                   │
                   ├──> ArticleOutlineService
                   │    - Uses: project.name, project.domain
                   │    - Uses: project.call_to_actions
                   │    - Uses: internal_link_opportunities from SERP
                   │
                   ├──> ArticleWriterService
                   │    - Uses: project.name (brand mentions)
                   │    - Uses: project.domain (CTAs)
                   │    - Uses: internal links from outline
                   │
                   └──> ArticleImprovementService
                        - Verifies: brand mention count
                        - Replaces: placeholder CTAs
                        - Adds: missing brand integration
```

---

## What's Actually in the Articles

### Current Article #14 Data Sources:

**SERP Research (91% utilized):**
- ✅ 8 company examples (Dropbox, Zappos, Buffer, etc.)
- ✅ 15 statistics with sources
- ✅ 8 recommended tools
- ✅ 8 FAQs
- ✅ 4 step-by-step guides
- ✅ 2 comparison tables

**Project Data (NEW - Phase 1):**
- ✅ Brand name: SignalLab (will appear 2-5x)
- ✅ Domain: signallab.app (for CTAs)
- ✅ CTAs: From project.call_to_actions

**Internal Links (already working):**
- ✅ Existing articles: Up to 50 from same project
- ✅ AI suggests 3-5 contextual internal links
- ✅ Based on article topics/headings

---

## Summary: What We Pull from Your Site

### ✅ Currently Pulling:
1. **Your completed articles** (title, URL, topics, meta)
2. **Your project CTAs** (text, URL, placement)
3. **Your brand name** (for mentions)
4. **Your domain** (for links)

### ❌ NOT Pulling (yet):
1. Sitemap.xml URLs
2. Pricing page content
3. Feature descriptions
4. Homepage content
5. External pages/resources

### 🚀 Phase 2 Would Add:
- Sitemap scraper to discover ALL pages
- Semantic matching for better internal links
- Pricing/feature extraction for accurate CTAs
- Homepage value prop for brand positioning

---

**Current state: Using EXISTING article database + project metadata**
**Phase 2 goal: Add real-time sitemap scraping for comprehensive internal linking**
