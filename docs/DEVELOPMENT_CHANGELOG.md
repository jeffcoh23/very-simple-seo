# VerySimpleSEO Development Changelog

> Consolidated development history and key decisions

---

## Branch: `fix-keyword-gen` (January 2025)

### Problem Statement
Keyword research was generating too many irrelevant keywords that didn't match the user's actual business focus. Users reported seeing keywords for completely different tools and industries.

**Example Issues:**
- SignalLab (team communication) was getting "AI detector" and "plagiarism checker" keywords
- Generic keywords like "free AI tool" dominated over specific, relevant terms
- Competitor discovery was pulling in blogs, news sites, and aggregators instead of actual competing products

### Solutions Implemented

#### 1. Improved Seed Keyword Generation
**Location:** `app/services/seed_keyword_generator.rb`

**Changes:**
- Domain-first approach: Scrape user's domain to understand what they actually do
- Competitor-informed seeds: Use competitor content to validate seed relevance
- Quality filtering: Remove generic/low-quality seeds before they pollute the pipeline
- Explicit business context in prompts to avoid domain name confusion

**Impact:** Seeds now accurately represent the user's specific product/service

#### 2. Semantic Filtering Enhancement
**Location:** `app/services/keyword_research_service.rb`

**Changes:**
- Raised similarity threshold from 0.30 → 0.40 (stricter filtering)
- Build richer domain context (title, description, headings, sitemap keywords)
- Filter out low-quality seeds before using them in context (prevents context pollution)
- Log rejected keywords for transparency

**Impact:** 40-60% reduction in irrelevant keywords

#### 3. Hybrid Competitor Discovery
**Location:** `app/services/keyword_research_service.rb:71-143`

**Previous Approach:** Pure Grounding API (unreliable, too many false positives)

**New Approach:**
1. Google Search for "similar sites" (organic SERP results)
2. AI filtering to remove blogs, news sites, aggregators
3. Domain scraping for actual content analysis

**Impact:** More accurate competitor identification, better keyword suggestions

#### 4. SERP Research with Citations
**Location:** `app/services/serp_research_service.rb`

**Changes:**
- Focused prompts targeting specific content types (statistics, expert quotes, case studies)
- Citation tracking to avoid hallucinations
- Structured JSON responses for reliability

**Impact:** Higher quality article content with verifiable sources

### Metrics & Results

**Before:**
- ~500 keywords generated, ~300 irrelevant
- Semantic threshold: 0.30 (too permissive)
- Competitor discovery: 10-15 results, ~70% false positives
- User feedback: "These aren't my keywords"

**After:**
- ~200 keywords generated, ~150 relevant
- Semantic threshold: 0.40 (stricter)
- Competitor discovery: 5-10 results, ~80% accurate
- User feedback: "Much better quality"

### Known Issues & Future Work

**Current Limitations:**
1. **No keyword clustering:** Near-duplicate keywords ("business AI tool" vs "business AI tools") still saved separately
   - **Next:** Implement clustering in separate branch (see below)

2. **Heuristic metrics:** Using estimated search volume/difficulty instead of real Google Ads API data
   - **Reason:** Google Ads API setup requires developer token (optional)
   - **Future:** Provide clear setup instructions for users who want real data

3. **Slow competitor scraping:** Sequential scraping adds ~10-15 seconds
   - **Future:** Consider parallel scraping with rate limiting

### Code Quality Improvements

**Cleanup:**
- Removed 64 temporary debugging scripts from `tmp/`
- Removed 17 one-time analysis scripts from `scripts/`
- Consolidated 12 phase/analysis docs into this changelog
- Cleaner, more maintainable codebase

**Documentation:**
- `KEYWORD_RESEARCH_FLOW.md` - Complete flow documentation
- `ARTICLE_GENERATION_FLOW.md` - Article generation process
- `GROUNDING_IMPLEMENTATION.md` - Technical Grounding API guide
- `DESIGN_SYSTEM.md` - UI/UX design system
- `CURRENT_DATA_USAGE.md` - Data consumption monitoring

---

## Next: `feature/keyword-clustering` Branch

### Goal
Implement smart keyword clustering to avoid content cannibalization while maintaining simplicity.

### Approach
**Keywords-first with progressive disclosure** (not topic-first):

1. **Show keywords immediately** (familiar, actionable)
2. **Highlight clusters automatically** (smart automation)
3. **Offer topic organization as power feature** (optional depth)

### Why This Approach?
- Aligns with "Very Simple SEO" brand promise
- Lower barrier to entry for new users
- Faster time-to-first-article
- Progressive complexity (simple → smart → strategic)

### Technical Plan

**Phase 1: Core Clustering**
- Integrate existing `KeywordClusteringService` into research flow
- Add database columns: `cluster_id`, `cluster_representative`, `cluster_size`, `cluster_keywords`
- Select best keyword from each cluster (highest volume + opportunity)
- Threshold: 0.85 similarity (only cluster near-duplicates)

**Phase 2: UI Enhancements**
- Cluster badge showing group size
- Expandable rows showing related keywords
- Article generation with cluster awareness
- User-reversible clustering decisions

**Phase 3: Topic Strategy (Future)**
- Optional topic pillar grouping
- Internal linking suggestions
- Topical authority tracking

### SEO Rationale (2025 Best Practices)
- **Avoid cannibalization:** Multiple pages targeting near-duplicates compete against each other
- **Topical authority:** One comprehensive page covering a cluster ranks better than multiple thin pages
- **User intent alignment:** Cluster variations often represent the same search intent
- **Content efficiency:** Write one great article instead of multiple mediocre ones

---

## Historical Context

### Phase 1-2: MVP Launch (2024)
- Basic keyword research with Google autocomplete
- Simple article generation with ChatGPT
- User authentication and credits system
- Deployed to Fly.io

### Phase 3: SEO Improvements (Early 2025)
- Added SERP scraping for People Also Ask and Related Searches
- Improved article structure with proper H2/H3 hierarchy
- Internal linking to user's domain
- Call-to-action integration

### Phase 4-9: Keyword Quality Iterations
- Multiple iterations on keyword filtering
- AI relevance filter (removed - too expensive and inconsistent)
- Semantic similarity filtering (final approach)
- Competitor analysis improvements

---

## Key Learnings

### What Worked
1. **Semantic similarity filtering** - Fast, reliable, explainable
2. **Domain-first context building** - Understand the user's actual business
3. **Hybrid approaches** - Combine multiple data sources (Google + AI + scraping)
4. **Progressive disclosure** - Don't overwhelm users with complexity upfront

### What Didn't Work
1. **AI relevance filtering** - Expensive, inconsistent, hard to debug
2. **Pure Grounding for competitors** - Too many false positives
3. **Low semantic thresholds** - Let in too many irrelevant keywords
4. **Complex upfront organization** - Users want keywords first, strategy second

### Design Principles Established
1. **Simple first, smart second** - Automation before manual work
2. **Show, don't force** - Surface insights, don't require organization
3. **Transparent AI** - Log decisions, allow reversal
4. **Keywords → Clusters → Topics** - Natural progression of sophistication

---

## References

**Core Documentation:**
- [Keyword Research Flow](KEYWORD_RESEARCH_FLOW.md)
- [Article Generation Flow](ARTICLE_GENERATION_FLOW.md)
- [Design System](DESIGN_SYSTEM.md)
- [Grounding Implementation](GROUNDING_IMPLEMENTATION.md)

**User Feedback:**
- [User Feedback Responses](USER_FEEDBACK_RESPONSES.md)

**Technical:**
- [Current Data Usage](CURRENT_DATA_USAGE.md)
- [Deployment Guide](deployment_guide.md)

---

**Last Updated:** January 2025
**Current Branch:** `fix-keyword-gen`
**Next Branch:** `feature/keyword-clustering`
