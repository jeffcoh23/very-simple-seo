# Keyword Clustering

> Automatically groups similar keywords to reduce noise and improve content strategy focus.

---

## Overview

The keyword clustering feature uses semantic similarity to group near-duplicate keywords together, presenting users with the most representative keyword from each cluster while hiding similar variations by default.

**Benefits:**
- **Reduces keyword noise** - Hides "seo tools", "tool for seo", "seo tool" variations
- **Improves decision-making** - Users see unique opportunities, not duplicates
- **Progressive disclosure** - Advanced users can expand clusters to see all variations
- **Better content strategy** - Focus on unique topics, not keyword variations

---

## Architecture

### Database Schema

```sql
-- Added to keywords table
cluster_id integer                     # Groups related keywords
is_cluster_representative boolean      # True for the "best" keyword in cluster
cluster_size integer                   # Number of keywords in this cluster
cluster_keywords jsonb                 # Array of sibling keyword texts
```

**Index:** `cluster_id` is indexed for fast cluster lookups.

### Models

**Keyword model** (`app/models/keyword.rb`):

```ruby
# Scopes
scope :cluster_representatives     # Only cluster reps
scope :in_cluster(id)              # Keywords in specific cluster
scope :unclustered                 # Keywords not in any cluster

# Methods
clustered?                         # Has cluster_id?
cluster_siblings                   # Other keywords in same cluster
cluster_representative             # Get the rep for this cluster
cluster_members                    # All keywords in cluster (including self)
```

### Services

**KeywordClusterAssignmentService** (`app/services/keyword_cluster_assignment_service.rb`):

- **Runs during:** Keyword research (Step 9, after filtering)
- **Similarity threshold:** 0.85 (very high - only near-duplicates cluster)
- **Max cluster size:** 10 keywords
- **Representative selection:** Highest `volume × opportunity`, prefer shorter keywords

**Algorithm:**
1. Load all keywords from research
2. Calculate semantic similarity between all pairs (OpenAI embeddings)
3. Group keywords with similarity ≥ 0.85
4. Assign unique cluster IDs
5. Select best representative for each cluster
6. Store cluster metadata (size, sibling keywords)

---

## User Interface

### Default View: Representatives Only

**URL:** `/projects/:id?tab=keywords`

Shows:
- Cluster representatives (one per cluster)
- Unclustered keywords
- Badge showing "+N variations" for clustered keywords

### Expanded View: All Keywords

**URL:** `/projects/:id?tab=keywords&view=all`

Shows:
- All keywords (both reps and cluster members)
- Expandable cluster rows

### Cluster Expansion

Clicking a clustered keyword row expands to show:
- All similar keyword variations
- Visual indication (indented, muted background)
- "variation" badge for non-representatives

---

## Controller Implementation

**ProjectsController#show** (`app/controllers/projects_controller.rb:38-71`):

```ruby
# Handle view parameter
view = params[:view] || "representatives"

# Load keywords based on view
@keywords = if view == "all"
  @project.keywords.by_opportunity.limit(50)
else
  # Default: representatives + unclustered
  @project.keywords
    .where("is_cluster_representative = ? OR cluster_id IS NULL", true)
    .by_opportunity
    .limit(50)
end

# Include stats for UI
stats: {
  total_keywords: @project.keywords.count,
  cluster_representatives: @project.keywords.cluster_representatives.count,
  unclustered: @project.keywords.unclustered.count
}
```

---

## Frontend Implementation

**Show.jsx** (`app/frontend/pages/App/Projects/Show.jsx`):

**State:**
```javascript
const [expandedClusters, setExpandedClusters] = useState(new Set())
```

**View Toggle:**
```javascript
const toggleView = () => {
  const newView = view === "representatives" ? "all" : "representatives"
  router.visit(`${project.routes.project}?tab=keywords&view=${newView}`, {
    preserveState: true,
    preserveScroll: true
  })
}
```

**Cluster Expansion:**
```javascript
const toggleCluster = (clusterId) => {
  setExpandedClusters(prev => {
    const next = new Set(prev)
    if (next.has(clusterId)) {
      next.delete(clusterId)
    } else {
      next.add(clusterId)
    }
    return next
  })
}
```

---

## Testing

### Model Tests

**File:** `test/models/keyword_test.rb`

Tests:
- ✅ `cluster_representatives` scope
- ✅ `in_cluster` scope
- ✅ `unclustered` scope
- ✅ `clustered?` method
- ✅ `cluster_siblings` method
- ✅ `cluster_representative` method
- ✅ `cluster_members` method

### Service Tests

**File:** `test/services/keyword_cluster_assignment_service_test.rb`

Tests:
- ✅ Skips clustering when no keywords
- ✅ Does not cluster single keyword
- ✅ Clusters similar keywords (≥0.85 similarity)
- ✅ Does not cluster dissimilar keywords (<0.85)
- ✅ Selects representative with highest score
- ✅ Prefers shorter keywords when scores equal
- ✅ Limits cluster size to 10 keywords
- ✅ Creates multiple clusters for different groups
- ✅ Handles nil/empty keywords gracefully
- ✅ Stores cluster keywords as array
- ✅ Assigns unique cluster IDs
- ✅ Performance test (50 keywords < 5s)

**Run tests:**
```bash
bin/rails test test/models/keyword_test.rb
bin/rails test test/services/keyword_cluster_assignment_service_test.rb
```

---

## Configuration

### Similarity Threshold

**Current:** 0.85 (very high - only near-duplicates)

**Rationale:**
- 0.40 threshold used for filtering (removes low-quality keywords)
- 0.85 threshold for clustering (groups near-duplicates only)
- Keeps clustering separate from filtering

**Tuning:**
```ruby
# app/services/keyword_cluster_assignment_service.rb
SIMILARITY_THRESHOLD = 0.85  # Adjust here
```

### Max Cluster Size

**Current:** 10 keywords per cluster

**Rationale:**
- Prevents UI overload when expanded
- Rare in practice (most clusters have 2-4 keywords)

**Tuning:**
```ruby
# app/services/keyword_cluster_assignment_service.rb
MAX_CLUSTER_SIZE = 10  # Adjust here
```

---

## URL Structure

**Keywords tab (default view):**
```
/projects/123
/projects/123?tab=keywords
/projects/123?tab=keywords&view=representatives
```

**Keywords tab (all variations):**
```
/projects/123?tab=keywords&view=all
```

**Articles tab:**
```
/projects/123?tab=articles
```

**Browser history:** Fully supported via query parameters

---

## Migration

**Generated:** `db/migrate/20251020005726_add_clustering_to_keywords.rb`

```bash
# Run migration
bin/rails db:migrate

# Rollback if needed
bin/rails db:rollback
```

**Applying to existing projects:**

Clustering runs automatically for new keyword research. For existing projects:

```ruby
# In Rails console
KeywordResearch.find_each do |research|
  next if research.keywords.cluster_representatives.any?

  KeywordClusterAssignmentService.new(research).perform
end
```

---

## Performance Considerations

**Clustering complexity:** O(n²) for n keywords

**Mitigations:**
- Runs asynchronously during keyword research job
- Semantic similarity service batches API calls
- Max 50 keywords shown in UI (pagination)
- Cluster expansion is client-side (no server call)

**Typical performance:**
- 20 keywords: ~2 seconds
- 50 keywords: ~5 seconds
- 100 keywords: ~10 seconds

---

## Future Enhancements

**Potential improvements:**
1. **Cluster naming** - Auto-generate cluster names from representatives
2. **Manual clustering** - Allow users to manually group/ungroup keywords
3. **Cluster analytics** - Show combined metrics for entire cluster
4. **Article generation from clusters** - Generate one article targeting all cluster variations
5. **Cluster filtering** - Filter by cluster size, similarity threshold

---

## Troubleshooting

**Issue:** Clustering not working

**Check:**
1. Migration applied? `bin/rails db:migrate:status`
2. Semantic similarity service configured?
3. Keywords exist in research?
4. Check logs for errors during keyword research job

**Issue:** Too many/few clusters

**Solution:** Adjust `SIMILARITY_THRESHOLD` in service:
- Higher threshold (0.90): Fewer, tighter clusters
- Lower threshold (0.75): More, looser clusters

**Issue:** Wrong keyword selected as representative

**Check:**
- Representative selection logic uses `volume × opportunity`
- Prefers shorter keywords when scores equal
- Modify `select_representative` method in service if needed

---

**Last Updated:** January 2025
**Feature Branch:** `fix-keyword-gen` (merged into main)
