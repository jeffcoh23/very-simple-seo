# VerySimpleSEO - Product Plan

## The Core Problem
Solopreneurs and indie hackers know they should do SEO, but:
- Keyword research is overwhelming (too many tools, too expensive)
- Writing SEO content takes forever
- They're not sure if they're targeting the right keywords
- They just want to ship content and rank, not become SEO experts

## The Solution Flow

### 1. **Get Started (5 minutes)**
- Sign up with email
- Create your first project (e.g., "My SaaS Landing Page")
- Enter your website URL (e.g., signallab.app)
- We automatically find 3-5 competitors OR you can add your own
- Hit "Research Keywords"

### 2. **See Your Opportunities (Instant)**
You land on a dashboard showing:
- **30 keyword opportunities** ranked by "how easy to win"
- Each keyword shows:
  - Search volume (how many people search this)
  - Difficulty score (how hard to rank)
  - Opportunity score (our recommendation)
  - Why it matters (commercial intent, informational, etc.)
- Sorted by opportunity score (best ones first)
- Visual indicators: 🟢 Easy wins, 🟡 Medium effort, 🔴 Hard

### 3. **Pick a Keyword & Generate**
- Click "Write Article" on any keyword
- We show you:
  - What's currently ranking (top 10 results)
  - Common topics they cover
  - Gaps you can exploit
- Confirm or tweak the approach
- Hit "Generate Article" (takes 2-3 minutes)

### 4. **Review & Export**
- See the full article with:
  - SEO-optimized title & meta description
  - Complete outline with sections
  - Written content in your style (if you provide sample writing)
  - Placeholders for screenshots/tools you might add
- Light editing tools (fix typos, adjust tone)
- Export options:
  - Copy to clipboard
  - Download as Markdown
  - Download as HTML

### 5. **Track Progress**
- Mark keywords as "Published" when you use them
- See which keywords you've covered vs. opportunities remaining

## Key Screens

1. **Projects Dashboard** - List of your websites
2. **Project Overview** - One project, showing keyword opportunities
3. **Keyword Detail** - Deep dive on one keyword before writing
4. **Article Generator** - Loading screen while we research & write
5. **Article Editor** - Review/edit the generated article
6. **Published Articles** - Track what you've shipped

## What Makes This Different

**For the user:**
- No analysis paralysis - we tell you exactly what to write
- One click from keyword → full article
- Affordable (under $50/month or one-time purchase)
- Works for any niche (SaaS, blogs, local businesses)

**Under the hood (not visible to user):**
- Real SERP research (we actually fetch top articles)
- Extracts real examples and stats from competitors
- Uses your writing voice if you provide samples
- Focuses on winnable keywords (not impossible ones)

## MVP Scope (4-6 weeks)

### Must Have:
- ✅ User accounts & auth
- ✅ Create/manage projects (one website per project)
- ✅ Run keyword research for a project
- ✅ View keyword opportunities (sorted table)
- ✅ Generate article for one keyword
- ✅ View/edit/export article
- ✅ Mark keywords as "published"

### Nice to Have (v2):
- Track rankings over time
- Competitor monitoring
- Publishing integrations (WordPress, Ghost)
- Team collaboration
- Custom voice training (upload 20+ articles)

### Explicitly NOT in MVP:
- Complex analytics
- Social sharing
- Backlink monitoring
- Multi-user/teams
- White-label

## Pricing Ideas (pick one for MVP)

### Option 1: Simple Monthly
- Free: 1 project, 5 articles/month
- Pro: $29/month - 3 projects, 20 articles/month
- Premium: $79/month - 10 projects, unlimited articles

### Option 2: Pay Per Article
- $5 per article generated
- Buy in packs (10 articles for $40, etc.)

### Option 3: Launch Special
- Lifetime deal: $99 one-time (unlimited projects, 50 articles/month)
- Acquire early users, validate product-market fit

## Success Metrics for MVP

- **10 paying customers** in first month
- **Average 5 articles generated per user**
- **80%+ satisfaction** (simple survey after article generation)
- **Users publish at least 3 articles** within 30 days

---

## Technical Architecture (High-Level)

### Stack
- Rails 8 + Postgres (existing template)
- Inertia + React + shadcn/ui (existing template)
- Background jobs for keyword research & article generation
- OpenAI GPT-4o + Gemini 2.0 Flash (cost optimization)
- Google Custom Search API (SERP research)

### Core Models
- **User** - Authentication (existing)
- **Project** - One website/domain
- **Competitor** - Competitor sites for a project
- **KeywordResearch** - One research run per project
- **Keyword** - Individual keyword opportunity
- **Article** - Generated article for a keyword

### Key Services (from bin/ scripts)
- `KeywordResearchService` - Adapts `bin/keyword_research`
- `ArticleGenerationService` - Adapts `bin/generate_article`
- `SerpAnalysisService` - Google search + scraping
- `VoiceAnalysisService` - Optional voice matching

### Jobs
- `KeywordResearchJob` - Runs in background (5-10 min)
- `ArticleGenerationJob` - Runs in background (2-3 min)

---

## Next Steps

1. Write detailed technical roadmap
2. Create database schema
3. Build MVP features in order
4. Launch to 10 beta users
5. Iterate based on feedback
