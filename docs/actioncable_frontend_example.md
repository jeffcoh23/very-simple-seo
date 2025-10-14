# ActionCable Frontend Integration

## Overview

Phase 4 is complete! Real-time updates are now working via Solid Cable.

**What's implemented:**
- ✅ KeywordResearchChannel - broadcasts keyword research progress
- ✅ ArticleChannel - broadcasts article generation progress
- ✅ User authentication/authorization in channels
- ✅ Broadcasting in background jobs
- ✅ Tested and working

## Frontend Integration with React

### 1. Install ActionCable Package

```bash
npm install @rails/actioncable
```

### 2. Example: Subscribe to Keyword Research Updates

```jsx
// app/frontend/pages/App/Projects/Show.jsx
import { useEffect, useState } from "react";
import { createConsumer } from "@rails/actioncable";
import { usePage } from "@inertiajs/react";

export default function ProjectShow() {
  const { project, keywordResearch } = usePage().props;
  const [researchStatus, setResearchStatus] = useState(keywordResearch?.status);
  const [keywordsFound, setKeywordsFound] = useState(keywordResearch?.total_keywords_found || 0);

  useEffect(() => {
    // Don't subscribe if research is already completed
    if (!keywordResearch || keywordResearch.status === 'completed') return;

    // Create cable connection
    const cable = createConsumer();

    // Subscribe to the KeywordResearchChannel
    const subscription = cable.subscriptions.create(
      {
        channel: "KeywordResearchChannel",
        id: keywordResearch.id
      },
      {
        received(data) {
          console.log("Received broadcast:", data);

          // Update local state
          setResearchStatus(data.status);
          setKeywordsFound(data.total_keywords_found || 0);

          // If completed, reload the page to get fresh keywords
          if (data.status === 'completed') {
            window.location.reload();
            // OR use Inertia's reload:
            // router.reload({ only: ['keywords', 'keywordResearch'] });
          }
        },

        connected() {
          console.log("Connected to KeywordResearchChannel");
        },

        disconnected() {
          console.log("Disconnected from KeywordResearchChannel");
        }
      }
    );

    // Cleanup: unsubscribe when component unmounts
    return () => {
      subscription.unsubscribe();
      cable.disconnect();
    };
  }, [keywordResearch?.id]);

  return (
    <div>
      {researchStatus === 'processing' && (
        <div className="bg-blue-50 border border-blue-200 rounded-lg p-4">
          <div className="flex items-center gap-3">
            <div className="animate-spin h-5 w-5 border-2 border-blue-500 border-t-transparent rounded-full"></div>
            <div>
              <h3 className="font-semibold">Researching keywords...</h3>
              <p className="text-sm text-muted-foreground">
                Found {keywordsFound} keywords so far
              </p>
            </div>
          </div>
        </div>
      )}

      {researchStatus === 'completed' && (
        <div className="bg-green-50 border border-green-200 rounded-lg p-4">
          <h3 className="font-semibold text-green-900">
            ✅ Research complete! Found {keywordsFound} keywords
          </h3>
        </div>
      )}

      {/* Keywords table goes here */}
    </div>
  );
}
```

### 3. Example: Subscribe to Article Generation Updates

```jsx
// app/frontend/pages/App/Articles/Show.jsx
import { useEffect, useState } from "react";
import { createConsumer } from "@rails/actioncable";
import { usePage } from "@inertiajs/react";

export default function ArticleShow() {
  const { article } = usePage().props;
  const [articleStatus, setArticleStatus] = useState(article.status);
  const [wordCount, setWordCount] = useState(article.word_count || 0);
  const [generationCost, setGenerationCost] = useState(article.generation_cost || 0);

  useEffect(() => {
    // Don't subscribe if article is already completed
    if (article.status === 'completed' || article.status === 'failed') return;

    const cable = createConsumer();

    const subscription = cable.subscriptions.create(
      {
        channel: "ArticleChannel",
        id: article.id
      },
      {
        received(data) {
          console.log("Article update:", data);

          setArticleStatus(data.status);
          setWordCount(data.word_count || 0);
          setGenerationCost(data.generation_cost || 0);

          // Reload page when generation completes
          if (data.status === 'completed' || data.status === 'failed') {
            window.location.reload();
          }
        },

        connected() {
          console.log("Connected to ArticleChannel");
        },

        disconnected() {
          console.log("Disconnected from ArticleChannel");
        }
      }
    );

    return () => {
      subscription.unsubscribe();
      cable.disconnect();
    };
  }, [article.id]);

  return (
    <div>
      {articleStatus === 'generating' && (
        <div className="bg-blue-50 border border-blue-200 rounded-lg p-4 mb-6">
          <div className="flex items-center gap-3">
            <div className="animate-spin h-5 w-5 border-2 border-blue-500 border-t-transparent rounded-full"></div>
            <div>
              <h3 className="font-semibold">Generating article...</h3>
              <p className="text-sm text-muted-foreground">
                This takes about 3 minutes. We're researching competitors, creating an outline, and writing your article.
              </p>
              {wordCount > 0 && (
                <p className="text-sm text-muted-foreground mt-1">
                  Progress: {wordCount} words written
                </p>
              )}
            </div>
          </div>
        </div>
      )}

      {articleStatus === 'completed' && (
        <div className="bg-green-50 border border-green-200 rounded-lg p-4 mb-6">
          <h3 className="font-semibold text-green-900">
            ✅ Article complete! {wordCount} words generated for ${generationCost.toFixed(2)}
          </h3>
        </div>
      )}

      {/* Article content editor goes here */}
    </div>
  );
}
```

## Broadcast Data Structure

### KeywordResearchChannel broadcasts:
```javascript
{
  id: 123,
  status: "processing" | "completed" | "failed",
  total_keywords_found: 190,
  started_at: "2025-10-11T23:00:00.000Z",
  completed_at: "2025-10-11T23:01:42.000Z",
  error_message: null
}
```

### ArticleChannel broadcasts:
```javascript
{
  id: 456,
  status: "generating" | "completed" | "failed",
  word_count: 2070,
  generation_cost: 0.41,
  started_at: "2025-10-11T23:10:00.000Z",
  completed_at: "2025-10-11T23:13:20.000Z",
  error_message: null
}
```

## Security

- Channels enforce user authorization via `current_user`
- Users can only subscribe to their own project's resources
- Unauthorized subscriptions are rejected automatically

## Benefits

- ✅ **No polling** - Server pushes updates to clients
- ✅ **Real-time** - Users see progress instantly
- ✅ **Efficient** - Uses WebSockets (persistent connection)
- ✅ **Scalable** - Solid Cable uses PostgreSQL (no Redis needed)
- ✅ **Production-ready** - Same setup works in development and production

## Testing Broadcasts

You can test broadcasts in the Rails console:

```ruby
# Get a keyword research
research = KeywordResearch.find(1)

# Manually broadcast an update
KeywordResearchChannel.broadcast_to(
  research,
  {
    id: research.id,
    status: "processing",
    total_keywords_found: 50
  }
)

# Any subscribers will receive this update instantly!
```

## Next Steps (Phase 5)

Now that real-time updates are working, we can build the controllers and UI:

1. Create ProjectsController (index, new, create, show)
2. Create ArticlesController (create, show, export)
3. Build React pages with ActionCable subscriptions
4. Show loading states during background jobs
5. Auto-reload data when jobs complete

**Phase 4 Complete!** 🎉
