# Testing Plan for VerySimpleSEO

## Current Status: 0% Test Coverage ⚠️

We have **zero tests** currently. The roadmap schedules testing for Phase 8 (Days 20-22), but we should add tests as we go.

## Priority Test Coverage Needed

### 1. Model Tests (Critical)

**User Model** (`test/models/user_test.rb`):
- ✅ Validations (email format, uniqueness, password length)
- ✅ Credits system (has_credits?, deduct_credit!, add_credits!)
- ✅ Plan helpers (free_plan?, paid_plan?, plan_name)
- ✅ Job priority

**Project Model** (`test/models/project_test.rb`):
- Validations (name, domain presence and format)
- Associations (competitors, keyword_researches, keywords, articles)
- Cascade deletes

**Keyword Model** (`test/models/keyword_test.rb`):
- Scopes (by_opportunity, recommended, published, starred)
- Helper methods (easy_win?, difficulty_level, difficulty_badge_color)
- Enums (generation_status)

**Article Model** (`test/models/article_test.rb`):
- Uniqueness (one article per keyword)
- Enums (status)
- Export methods (export_markdown, export_html)

**KeywordResearch Model** (`test/models/keyword_research_test.rb`):
- Status transitions
- retry! method

### 2. Service Tests (High Priority)

**KeywordMetricsService** (`test/services/keyword_metrics_service_test.rb`):
- Heuristic calculations (volume, difficulty, CPC)
- Opportunity scoring
- Intent detection

**PlansService** (`test/services/plans_service_test.rb`):
- ✅ credits_for_plan (returns correct credits per plan)
- ✅ free_tier_credits
- Plan limits validation

### 3. Controller Tests (High Priority)

**ProjectsController** (`test/controllers/projects_controller_test.rb`):
- `index` - lists user's projects only
- `create` - enforces usage limits
- `create` - starts keyword research job
- `show` - returns proper props
- `update` - allows editing
- `destroy` - cascades correctly
- Security: users can only access their own projects

**ArticlesController** (`test/controllers/articles_controller_test.rb`):
- `create` - enforces credit limits
- `create` - deducts credit
- `create` - starts generation job
- `create` - prevents duplicate articles for same keyword
- `show` - returns proper props
- `export` - generates markdown file
- `export` - generates HTML file
- Security: users can only access their own articles

### 4. Job Tests (Medium Priority)

**KeywordResearchJob** (`test/jobs/keyword_research_job_test.rb`):
- Updates status to processing
- Broadcasts status updates via ActionCable
- Handles errors gracefully
- Sets error_message on failure

**ArticleGenerationJob** (`test/jobs/article_generation_job_test.rb`):
- Updates status to generating
- Broadcasts status updates via ActionCable
- Handles errors gracefully
- Tracks generation cost

### 5. Integration Tests (Medium Priority)

**Keyword Research Flow** (`test/integration/keyword_research_flow_test.rb`):
- User creates project
- Keyword research starts automatically
- Keywords are saved to database
- Real-time updates broadcast

**Article Generation Flow** (`test/integration/article_generation_flow_test.rb`):
- User selects keyword
- Credit is deducted
- Article generation starts
- Article is saved with proper content
- Real-time updates broadcast

### 6. Channel Tests (Low Priority)

**KeywordResearchChannel** (`test/channels/keyword_research_channel_test.rb`):
- User can subscribe to their own research
- User cannot subscribe to other users' research
- Broadcasts work correctly

**ArticleChannel** (`test/channels/article_channel_test.rb`):
- User can subscribe to their own articles
- User cannot subscribe to other users' articles
- Broadcasts work correctly

## Testing Tools Recommendations

```ruby
# Gemfile (test group)
group :test do
  gem "mocha"           # Mocking/stubbing
  gem "webmock"         # HTTP request stubbing
  gem "vcr"             # Record HTTP interactions
  gem "simplecov"       # Code coverage
  gem "shoulda-matchers" # Validation/association matchers
end
```

## Quick Wins for Immediate Testing

For Phase 8, prioritize these tests first:

1. **Model validations** (30 min) - Catch data integrity issues
2. **Controller security** (1 hr) - Ensure users can't access others' data
3. **Credits system** (30 min) - Critical business logic
4. **Job error handling** (30 min) - Background jobs must be resilient

**Total time: ~2.5 hours for critical coverage**

## Running Tests

```bash
# Run all tests
rails test

# Run specific test file
rails test test/models/user_test.rb

# Run with coverage
COVERAGE=true rails test

# Run in parallel (faster)
rails test --parallel
```

## Test Coverage Goal

- **Phase 8:** 60% coverage (models, controllers, critical paths)
- **Pre-launch:** 80% coverage (add service tests, integration tests)
- **Production:** 90%+ coverage (comprehensive)

## Note

The ad-hoc console tests we created were useful for initial development, but they're not replaceable for proper automated tests. We should:
1. Delete temporary test scripts (✅ done)
2. Add proper test suite in Phase 8
3. Run tests in CI/CD before deployment
