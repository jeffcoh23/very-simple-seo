import { useEffect, useState } from "react"
import { Link, usePage, router } from "@inertiajs/react"
import { createConsumer } from "@rails/actioncable"
import AppLayout from "@/layout/AppLayout"
import { Button } from "@/components/ui/button"
import { Card, CardHeader, CardTitle, CardContent } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { ArrowLeft, Loader2, Download, FileText, Eye, Trash2, RefreshCw, RotateCcw } from "lucide-react"

export default function ArticlesShow() {
  const { article, project, keyword } = usePage().props

  const [articleStatus, setArticleStatus] = useState(article.status)
  const [articleContent, setArticleContent] = useState(article.content)
  const [wordCount, setWordCount] = useState(article.word_count || 0)
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false)
  const [progressMessage, setProgressMessage] = useState("")
  const [progressLog, setProgressLog] = useState([])

  // Real-time updates via ActionCable
  useEffect(() => {
    if (article.status === 'completed' || article.status === 'failed') {
      return
    }

    const cable = createConsumer()
    const subscription = cable.subscriptions.create(
      {
        channel: "ArticleChannel",
        id: article.id
      },
      {
        received(data) {
          console.log("Article update:", data)

          setArticleStatus(data.status)
          setWordCount(data.word_count || 0)

          // Update progress message
          if (data.progress_message) {
            setProgressMessage(data.progress_message)
            setProgressLog(prev => [...prev, { time: new Date(), message: data.progress_message }])
          }

          // Reload page when generation completes
          if (data.status === 'completed' || data.status === 'failed') {
            setTimeout(() => {
              router.reload({ only: ['article'] })
            }, 1000)
          }
        },

        connected() {
          console.log("Connected to ArticleChannel")
        },

        disconnected() {
          console.log("Disconnected from ArticleChannel")
        }
      }
    )

    return () => {
      subscription.unsubscribe()
      cable.disconnect()
    }
  }, [article.id])

  const handleDelete = () => {
    if (showDeleteConfirm) {
      router.delete(article.routes.delete_article)
    } else {
      setShowDeleteConfirm(true)
      setTimeout(() => setShowDeleteConfirm(false), 3000)
    }
  }

  const getStatusBadge = () => {
    switch (articleStatus) {
      case 'pending':
        return <Badge className="bg-warning-soft text-warning border-2 border-warning/30 font-semibold">Pending</Badge>
      case 'generating':
        return <Badge className="bg-info-soft text-info border-2 border-info/30 font-semibold">Generating</Badge>
      case 'completed':
        return <Badge className="bg-success-soft text-success border-2 border-success/30 font-semibold">Completed</Badge>
      case 'failed':
        return <Badge className="bg-destructive-soft text-destructive border-2 border-destructive/30 font-semibold">Failed</Badge>
      default:
        return null
    }
  }

  return (
    <AppLayout>
      <div className="space-y-6">
        {/* Header */}
        <div>
          <Link href={article.routes.project} className="inline-flex items-center text-sm text-muted-foreground hover:text-primary transition-colors mb-4">
            <ArrowLeft className="mr-2 h-4 w-4" />
            Back to Project
          </Link>

          <div className="flex items-start justify-between">
            <div className="flex-1">
              <div className="flex items-center gap-3 mb-2">
                <h1 className="text-3xl font-display font-bold">
                  {article.title || "Generating Article..."}
                </h1>
                {getStatusBadge()}
              </div>
              <p className="text-muted-foreground">
                Keyword: <span className="font-medium">{keyword.keyword}</span>
              </p>
            </div>

            {articleStatus === 'completed' && (
              <div className="flex gap-2">
                <Button variant="outline" className="border-2" asChild>
                  <a href={article.routes.export_markdown} download>
                    <Download className="mr-2 h-4 w-4" />
                    Export MD
                  </a>
                </Button>
                <Button variant="outline" className="border-2" asChild>
                  <a href={article.routes.export_html} download>
                    <Download className="mr-2 h-4 w-4" />
                    Export HTML
                  </a>
                </Button>
                <Button
                  variant={showDeleteConfirm ? "destructive" : "outline"}
                  className="border-2"
                  onClick={handleDelete}
                >
                  <Trash2 className="mr-2 h-4 w-4" />
                  {showDeleteConfirm ? "Confirm?" : "Delete"}
                </Button>
              </div>
            )}
          </div>
        </div>

        {/* Generation Status */}
        {articleStatus === 'pending' && (
          <Card className="bg-warning-soft border-2 border-warning/30">
            <CardContent className="py-4">
              <div className="flex items-center gap-3">
                <Loader2 className="h-5 w-5 animate-spin text-warning" />
                <div>
                  <h3 className="font-semibold text-warning">Article queued for generation</h3>
                  <p className="text-sm text-warning">
                    Your article will start generating shortly...
                  </p>
                </div>
              </div>
            </CardContent>
          </Card>
        )}

        {articleStatus === 'generating' && (
          <Card className="bg-info-soft border-2 border-info/30">
            <CardContent className="py-4">
              <div className="flex items-start gap-3">
                <Loader2 className="h-5 w-5 animate-spin text-info mt-1" />
                <div className="flex-1">
                  <h3 className="font-semibold text-info">Generating article...</h3>
                  {progressMessage && (
                    <p className="text-sm text-info mt-1 font-medium">{progressMessage}</p>
                  )}

                  {/* Progress Log */}
                  {progressLog.length > 0 && (
                    <div className="mt-3 space-y-1 max-h-48 overflow-y-auto bg-white/50 rounded p-2 border-2 border-info/30">
                      {progressLog.map((entry, index) => (
                        <div key={index} className="text-xs text-info font-mono">
                          <span className="text-info/60">{entry.time.toLocaleTimeString()}</span> {entry.message}
                        </div>
                      ))}
                    </div>
                  )}

                  <div className="mt-2 space-y-1">
                    <p className="text-xs text-info">
                      This takes about 1-5 minutes. We're researching competitors, creating an outline, and writing your article.
                    </p>
                    {wordCount > 0 && (
                      <p className="text-xs text-info">
                        Progress: {wordCount} words written
                      </p>
                    )}
                  </div>
                </div>
              </div>
            </CardContent>
          </Card>
        )}

        {articleStatus === 'failed' && article.error_message && (
          <Card className="bg-destructive-soft border-2 border-destructive/30">
            <CardContent className="py-4">
              <div className="flex items-start justify-between">
                <div className="flex-1">
                  <h3 className="font-semibold text-destructive">Generation failed</h3>
                  <p className="text-sm text-destructive mt-1">{article.error_message}</p>
                </div>
                <div className="flex gap-2 ml-4">
                  <Button
                    variant="outline"
                    className="border-2 border-destructive text-destructive hover:bg-destructive/10"
                    onClick={() => router.post(article.routes.retry_article)}
                  >
                    <RefreshCw className="mr-2 h-4 w-4" />
                    Retry
                  </Button>
                  <Button
                    variant="outline"
                    className="border-2 border-primary text-primary hover:bg-primary/10"
                    onClick={() => {
                      if (confirm("Regenerate from scratch? This will cost 1 credit.")) {
                        router.post(article.routes.regenerate_article)
                      }
                    }}
                  >
                    <RotateCcw className="mr-2 h-4 w-4" />
                    Regenerate
                  </Button>
                </div>
              </div>
            </CardContent>
          </Card>
        )}

        {/* Article Stats */}
        {articleStatus === 'completed' && (
          <div className="grid grid-cols-3 gap-4">
            <Card className="border-2">
              <CardContent className="pt-6">
                <div className="text-2xl font-bold">{wordCount}</div>
                <div className="text-sm text-muted-foreground">Words</div>
              </CardContent>
            </Card>
            <Card className="border-2">
              <CardContent className="pt-6">
                <div className="text-2xl font-bold">{keyword.volume?.toLocaleString() || "—"}</div>
                <div className="text-sm text-muted-foreground">Monthly Searches</div>
              </CardContent>
            </Card>
            <Card className="border-2">
              <CardContent className="pt-6">
                <div className="text-2xl font-bold">{keyword.difficulty}</div>
                <div className="text-sm text-muted-foreground">Keyword Difficulty</div>
              </CardContent>
            </Card>
          </div>
        )}

        {/* Meta Description */}
        {articleStatus === 'completed' && article.meta_description && (
          <Card className="border-2">
            <CardHeader>
              <CardTitle className="text-lg">Meta Description</CardTitle>
            </CardHeader>
            <CardContent>
              <p className="text-muted-foreground">{article.meta_description}</p>
            </CardContent>
          </Card>
        )}

        {/* Article Content */}
        {articleStatus === 'completed' && article.content && (
          <Card className="border-2">
            <CardHeader>
              <CardTitle>Article Content</CardTitle>
            </CardHeader>
            <CardContent>
              <div
                className="prose prose-lg max-w-none"
                dangerouslySetInnerHTML={{ __html: article.content }}
              />
            </CardContent>
          </Card>
        )}

        {/* Outline (while generating) */}
        {articleStatus === 'generating' && article.outline && (
          <Card className="border-2">
            <CardHeader>
              <CardTitle>Article Outline</CardTitle>
            </CardHeader>
            <CardContent>
              <pre className="text-sm bg-muted p-4 rounded-lg overflow-auto">
                {JSON.stringify(article.outline, null, 2)}
              </pre>
            </CardContent>
          </Card>
        )}
      </div>
    </AppLayout>
  )
}
