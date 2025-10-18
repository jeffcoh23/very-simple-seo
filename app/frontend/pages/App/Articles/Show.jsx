import { useEffect, useState } from "react"
import { Link, usePage, router } from "@inertiajs/react"
import { createConsumer } from "@rails/actioncable"
import ReactMarkdown from "react-markdown"
import remarkGfm from "remark-gfm"
import AppLayout from "@/layout/AppLayout"
import { Button } from "@/components/ui/button"
import { Card, CardHeader, CardTitle, CardContent, CardDescription } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { ArrowLeft, Loader2, Download, Eye, Trash2, RefreshCw, RotateCcw, Calendar, Clock, FileText, Target, ChevronUp, ChevronDown } from "lucide-react"

export default function ArticlesShow() {
  const { article, project, keyword } = usePage().props

  const [articleStatus, setArticleStatus] = useState(article.status)
  const [articleContent, setArticleContent] = useState(article.content)
  const [wordCount, setWordCount] = useState(article.word_count || 0)
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false)
  const [progressMessage, setProgressMessage] = useState("")
  const [progressLog, setProgressLog] = useState([])
  const [showOutline, setShowOutline] = useState(true)

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

  const formatDate = (dateString) => {
    if (!dateString) return "—"
    const date = new Date(dateString)
    return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric', hour: '2-digit', minute: '2-digit' })
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
              <h1 className="text-3xl font-display font-bold mb-2">
                {article.title || "Generating Article..."}
              </h1>
              <p className="text-muted-foreground">
                Keyword: <span className="font-medium font-mono">{keyword.keyword}</span>
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

        {/* Sidebar + Content Layout */}
        {articleStatus === 'completed' && (
          <div className="flex flex-col lg:flex-row gap-6">
            {/* Sidebar */}
            <aside className="lg:w-80 flex-shrink-0 space-y-6">
              {/* Status & Metadata */}
              <Card className="border-2">
                <CardHeader>
                  <div className="flex items-center justify-between">
                    <CardTitle className="text-lg">Status</CardTitle>
                    {getStatusBadge()}
                  </div>
                </CardHeader>
                <CardContent className="space-y-4">
                  <div className="flex items-start gap-3">
                    <FileText className="h-5 w-5 text-muted-foreground mt-0.5" />
                    <div>
                      <div className="text-sm text-muted-foreground">Word Count</div>
                      <div className="text-lg font-semibold">{wordCount}</div>
                    </div>
                  </div>

                  <div className="flex items-start gap-3">
                    <Target className="h-5 w-5 text-muted-foreground mt-0.5" />
                    <div>
                      <div className="text-sm text-muted-foreground">Target Words</div>
                      <div className="text-lg font-semibold">{article.target_word_count || "—"}</div>
                    </div>
                  </div>

                  <div className="flex items-start gap-3">
                    <Clock className="h-5 w-5 text-muted-foreground mt-0.5" />
                    <div>
                      <div className="text-sm text-muted-foreground">Started</div>
                      <div className="text-sm">{formatDate(article.started_at)}</div>
                    </div>
                  </div>

                  <div className="flex items-start gap-3">
                    <Calendar className="h-5 w-5 text-muted-foreground mt-0.5" />
                    <div>
                      <div className="text-sm text-muted-foreground">Completed</div>
                      <div className="text-sm">{formatDate(article.completed_at)}</div>
                    </div>
                  </div>
                </CardContent>
              </Card>

              {/* Keyword Info */}
              <Card className="border-2">
                <CardHeader>
                  <CardTitle className="text-lg">Keyword Data</CardTitle>
                </CardHeader>
                <CardContent className="space-y-3">
                  <div>
                    <div className="text-sm text-muted-foreground">Monthly Searches</div>
                    <div className="text-lg font-semibold">{keyword.volume?.toLocaleString() || "—"}</div>
                  </div>

                  <div>
                    <div className="text-sm text-muted-foreground">Difficulty</div>
                    <div className="text-lg font-semibold">{keyword.difficulty}</div>
                  </div>

                  <div>
                    <div className="text-sm text-muted-foreground">Opportunity Score</div>
                    <div className="text-lg font-semibold">{keyword.opportunity}</div>
                  </div>

                  <div>
                    <div className="text-sm text-muted-foreground">Intent</div>
                    <div className="text-sm font-medium capitalize">{keyword.intent}</div>
                  </div>
                </CardContent>
              </Card>

            </aside>

            {/* Main Content */}
            <div className="flex-1 space-y-6">
              {/* Meta Description */}
              {article.meta_description && (
                <Card className="border-2">
                  <CardHeader>
                    <CardTitle className="text-lg">Meta Description</CardTitle>
                  </CardHeader>
                  <CardContent>
                    <p className="text-muted-foreground">{article.meta_description}</p>
                  </CardContent>
                </Card>
              )}

              {/* Article Outline */}
              {article.outline && (
                <Card className="border-2 bg-warm">
                  <CardHeader className="cursor-pointer" onClick={() => setShowOutline(!showOutline)}>
                    <div className="flex items-center justify-between">
                      <div>
                        <CardTitle className="text-lg">Table of Contents</CardTitle>
                        <CardDescription>What you'll learn in this article</CardDescription>
                      </div>
                      {showOutline ? (
                        <ChevronUp className="h-5 w-5 text-muted-foreground" />
                      ) : (
                        <ChevronDown className="h-5 w-5 text-muted-foreground" />
                      )}
                    </div>
                  </CardHeader>
                  {showOutline && (
                    <CardContent>
                    <ol className="space-y-3 list-none">
                      {(() => {
                        // Handle different outline formats
                        let sections = []

                        if (Array.isArray(article.outline)) {
                          sections = article.outline
                        } else if (typeof article.outline === 'object' && article.outline.sections) {
                          sections = article.outline.sections
                        } else if (typeof article.outline === 'object') {
                          // Try to extract sections from object
                          sections = Object.values(article.outline).filter(item =>
                            typeof item === 'object' || typeof item === 'string'
                          )
                        }

                        return sections.map((section, index) => {
                          let heading = ''
                          let subheadings = []

                          if (typeof section === 'string') {
                            heading = section
                          } else if (section.heading) {
                            heading = section.heading
                            subheadings = section.subheadings || section.key_points || []
                          } else if (section.title) {
                            heading = section.title
                            subheadings = section.subsections || section.points || []
                          }

                          return (
                            <li key={index} className="flex gap-3">
                              <span className="flex-shrink-0 w-8 h-8 rounded-full bg-primary/10 text-primary flex items-center justify-center font-semibold text-sm">
                                {index + 1}
                              </span>
                              <div className="flex-1">
                                <div className="font-semibold text-foreground mb-1">{heading}</div>
                                {subheadings.length > 0 && (
                                  <ul className="space-y-1 ml-4">
                                    {subheadings.map((sub, subIndex) => (
                                      <li key={subIndex} className="text-sm text-muted-foreground flex gap-2">
                                        <span className="text-primary">•</span>
                                        <span>{typeof sub === 'string' ? sub : sub.heading || sub.title || sub}</span>
                                      </li>
                                    ))}
                                  </ul>
                                )}
                              </div>
                            </li>
                          )
                        })
                      })()}
                    </ol>
                  </CardContent>
                  )}
                </Card>
              )}

              {/* Article Content */}
              {article.content && (
                <Card className="border-2">
                  <CardHeader>
                    <CardTitle>Article Content</CardTitle>
                  </CardHeader>
                  <CardContent>
                    <div className="prose prose-lg max-w-none
                      prose-headings:font-display prose-headings:text-foreground prose-headings:tracking-tight
                      prose-h1:text-4xl prose-h1:font-bold prose-h1:mb-4 prose-h1:mt-8
                      prose-h2:text-3xl prose-h2:font-bold prose-h2:mb-3 prose-h2:mt-6
                      prose-h3:text-2xl prose-h3:font-semibold prose-h3:mb-2 prose-h3:mt-4
                      prose-p:text-foreground prose-p:leading-relaxed prose-p:mb-4
                      prose-strong:text-foreground prose-strong:font-semibold
                      prose-li:text-foreground prose-li:my-1
                      prose-ul:my-4 prose-ol:my-4
                      prose-a:text-primary prose-a:underline prose-a:font-medium
                      prose-code:text-foreground prose-code:bg-muted prose-code:px-1.5 prose-code:py-0.5 prose-code:rounded prose-code:text-sm prose-code:font-mono
                      prose-blockquote:border-l-4 prose-blockquote:border-primary prose-blockquote:pl-4 prose-blockquote:italic prose-blockquote:text-muted-foreground
                      prose-img:rounded-lg prose-img:shadow-md
                    ">
                      <ReactMarkdown
                        remarkPlugins={[remarkGfm]}
                        components={{
                          h1: ({node, ...props}) => <h1 className="scroll-mt-24" {...props} />,
                          h2: ({node, ...props}) => <h2 className="scroll-mt-24" {...props} />,
                          h3: ({node, ...props}) => <h3 className="scroll-mt-24" {...props} />,
                        }}
                      >
                        {article.content}
                      </ReactMarkdown>
                    </div>
                  </CardContent>
                </Card>
              )}
            </div>
          </div>
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
