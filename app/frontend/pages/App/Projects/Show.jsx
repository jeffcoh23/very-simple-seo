import { useEffect, useState, useRef } from "react"
import { Link, usePage, router } from "@inertiajs/react"
import { createConsumer } from "@rails/actioncable"
import AppLayout from "@/layout/AppLayout"
import { Button } from "@/components/ui/button"
import { Card, CardHeader, CardTitle, CardDescription, CardContent } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { ArrowLeft, Loader2, TrendingUp, Eye, Star, FileText, ChevronDown, ChevronUp } from "lucide-react"

export default function ProjectsShow() {
  const { project, keywordResearch, keywords } = usePage().props
  const { routes, auth } = usePage().props

  const [researchStatus, setResearchStatus] = useState(keywordResearch?.status)
  const [keywordsFound, setKeywordsFound] = useState(keywordResearch?.total_keywords_found || 0)
  const [progressMessage, setProgressMessage] = useState("")
  const [progressLog, setProgressLog] = useState(keywordResearch?.progress_log || [])
  const [showResearchLog, setShowResearchLog] = useState(false)
  const progressLogRef = useRef(null)

  // Auto-scroll progress log when new messages arrive
  useEffect(() => {
    if (progressLogRef.current) {
      progressLogRef.current.scrollTop = progressLogRef.current.scrollHeight
    }
  }, [progressLog])

  // Real-time updates via ActionCable
  useEffect(() => {
    if (!keywordResearch || keywordResearch.status === 'completed' || keywordResearch.status === 'failed') {
      return
    }

    const cable = createConsumer()
    const subscription = cable.subscriptions.create(
      {
        channel: "KeywordResearchChannel",
        id: keywordResearch.id
      },
      {
        received(data) {
          console.log("Keyword research update:", data)

          setResearchStatus(data.status)
          setKeywordsFound(data.total_keywords_found || 0)

          // Update progress message and log from server
          if (data.progress_message) {
            setProgressMessage(data.progress_message)
          }

          if (data.progress_log) {
            setProgressLog(data.progress_log)
          }

          // Reload page when research completes
          if (data.status === 'completed') {
            setTimeout(() => {
              router.reload({ only: ['keywords', 'keywordResearch', 'project'] })
            }, 1000)
          }
        },

        connected() {
          console.log("Connected to KeywordResearchChannel")
        },

        disconnected() {
          console.log("Disconnected from KeywordResearchChannel")
        }
      }
    )

    return () => {
      subscription.unsubscribe()
      cable.disconnect()
    }
  }, [keywordResearch?.id])

  const getIntentBadge = (intent) => {
    const colors = {
      informational: "bg-info-soft text-info border-2 border-info/30",
      commercial: "bg-success-soft text-success border-2 border-success/30",
      transactional: "bg-accent-soft text-accent border-2 border-accent/30",
      navigational: "bg-muted text-muted-foreground border-2"
    }
    return colors[intent] || colors.navigational
  }

  const getDifficultyBadge = (difficulty) => {
    if (difficulty <= 30) return { label: "Easy", color: "bg-success-soft text-success border-2 border-success/30 font-semibold" }
    if (difficulty <= 60) return { label: "Medium", color: "bg-warning-soft text-warning border-2 border-warning/30 font-semibold" }
    return { label: "Hard", color: "bg-destructive-soft text-destructive border-2 border-destructive/30 font-semibold" }
  }

  return (
    <AppLayout>
      <div className="space-y-6">
        {/* Header */}
        <div>
          <Link href={routes.projects} className="inline-flex items-center text-sm text-muted-foreground hover:text-primary transition-colors mb-4">
            <ArrowLeft className="mr-2 h-4 w-4" />
            Back to Projects
          </Link>

          <div className="flex items-start justify-between">
            <div>
              <h1 className="text-3xl font-display font-bold">{project.name}</h1>
              {project.domain && (
                <p className="text-muted-foreground mt-1">{project.domain}</p>
              )}
            </div>
            <Link href={project.routes.edit_project}>
              <Button variant="outline" className="border-2">Edit Project</Button>
            </Link>
          </div>

          {/* Project Stats */}
          <div className="grid grid-cols-3 gap-4 mt-6">
            <Card className="border-2">
              <CardContent className="pt-6">
                <div className="text-2xl font-bold">{project.keywords_count}</div>
                <div className="text-sm text-muted-foreground">Keywords</div>
              </CardContent>
            </Card>
            <Card className="border-2">
              <CardContent className="pt-6">
                <div className="text-2xl font-bold">{project.articles_count}</div>
                <div className="text-sm text-muted-foreground">Articles</div>
              </CardContent>
            </Card>
            <Card className="border-2">
              <CardContent className="pt-6">
                <div className="text-2xl font-bold">{auth.user.credits}</div>
                <div className="text-sm text-muted-foreground">Credits Remaining</div>
              </CardContent>
            </Card>
          </div>
        </div>

        {/* Research Status */}
        {researchStatus === 'processing' && (
          <Card className="bg-info-soft border-2 border-info/30">
            <CardContent className="py-4">
              <div className="flex items-start gap-3">
                <Loader2 className="h-5 w-5 animate-spin text-info mt-1" />
                <div className="flex-1">
                  <h3 className="font-semibold text-info">Researching keywords...</h3>
                  {progressMessage && (
                    <p className="text-sm text-info mt-1 font-medium">{progressMessage}</p>
                  )}

                  {/* Progress Log */}
                  {progressLog.length > 0 && (
                    <div
                      ref={progressLogRef}
                      className="mt-3 space-y-1 max-h-48 overflow-y-auto bg-white/50 rounded p-2 border-2 border-info/30 scroll-smooth"
                    >
                      {progressLog.map((entry, index) => {
                        const indent = entry.indent || 0
                        const paddingLeft = indent * 16 // 16px per indent level
                        return (
                          <div
                            key={index}
                            className="text-xs text-info font-mono"
                            style={{ paddingLeft: `${paddingLeft}px` }}
                          >
                            <span className="text-info/60">{new Date(entry.time).toLocaleTimeString()}</span> {entry.message}
                          </div>
                        )
                      })}
                    </div>
                  )}

                  <p className="text-xs text-info mt-2">
                    Found {keywordsFound} keywords so far. This usually takes about 1-3 minutes.
                  </p>
                </div>
              </div>
            </CardContent>
          </Card>
        )}

        {researchStatus === 'failed' && keywordResearch?.error_message && (
          <Card className="bg-destructive-soft border-2 border-destructive/30">
            <CardContent className="py-4">
              <h3 className="font-semibold text-destructive">Research failed</h3>
              <p className="text-sm text-destructive mt-1">{keywordResearch.error_message}</p>
            </CardContent>
          </Card>
        )}

        {/* Research Log (Expandable) - Show after completion or failure */}
        {(researchStatus === 'completed' || researchStatus === 'failed') && progressLog.length > 0 && (
          <Card className="border-2">
            <CardHeader className="cursor-pointer" onClick={() => setShowResearchLog(!showResearchLog)}>
              <div className="flex items-center justify-between">
                <div>
                  <CardTitle className="text-lg">Research Log</CardTitle>
                  <CardDescription>View detailed research process and decisions</CardDescription>
                </div>
                {showResearchLog ? (
                  <ChevronUp className="h-5 w-5 text-muted-foreground" />
                ) : (
                  <ChevronDown className="h-5 w-5 text-muted-foreground" />
                )}
              </div>
            </CardHeader>
            {showResearchLog && (
              <CardContent>
                <div className="space-y-1 max-h-96 overflow-y-auto bg-muted/30 rounded p-3 border">
                  {progressLog.map((entry, index) => {
                    const indent = entry.indent || 0
                    const paddingLeft = indent * 16
                    return (
                      <div
                        key={index}
                        className="text-xs font-mono text-muted-foreground"
                        style={{ paddingLeft: `${paddingLeft}px` }}
                      >
                        <span className="text-muted-foreground/60">{new Date(entry.time).toLocaleTimeString()}</span> {entry.message}
                      </div>
                    )
                  })}
                </div>
              </CardContent>
            )}
          </Card>
        )}

        {/* Keywords Table */}
        <Card className="border-2">
          <CardHeader>
            <CardTitle>Keywords</CardTitle>
            <CardDescription>
              Top keyword opportunities for your content strategy
            </CardDescription>
          </CardHeader>
          <CardContent>
            {keywords.length === 0 ? (
              <div className="text-center py-12 text-muted-foreground">
                <p>No keywords found yet. Research is in progress...</p>
              </div>
            ) : (
              <div className="overflow-x-auto">
                <table className="w-full">
                  <thead>
                    <tr className="border-b-2">
                      <th className="text-left py-3 px-4 font-semibold text-sm">Keyword</th>
                      <th className="text-left py-3 px-4 font-semibold text-sm">Intent</th>
                      <th className="text-center py-3 px-4 font-semibold text-sm">Volume</th>
                      <th className="text-center py-3 px-4 font-semibold text-sm">Difficulty</th>
                      <th className="text-center py-3 px-4 font-semibold text-sm">Opportunity</th>
                      <th className="text-center py-3 px-4 font-semibold text-sm">CPC</th>
                      <th className="text-right py-3 px-4 font-semibold text-sm">Action</th>
                    </tr>
                  </thead>
                  <tbody>
                    {keywords.map((keyword) => {
                      const difficultyBadge = getDifficultyBadge(keyword.difficulty)

                      return (
                        <tr key={keyword.id} className="border-b-2 hover:bg-muted/50 transition-colors">
                          <td className="py-3 px-4">
                            <div className="flex items-center gap-2">
                              {keyword.starred && (
                                <Star className="h-4 w-4 fill-accent text-accent" />
                              )}
                              <span className="font-medium">{keyword.keyword}</span>
                            </div>
                          </td>
                          <td className="py-3 px-4">
                            <Badge className={getIntentBadge(keyword.intent)}>
                              {keyword.intent}
                            </Badge>
                          </td>
                          <td className="py-3 px-4 text-center">
                            {keyword.volume ? keyword.volume.toLocaleString() : "—"}
                          </td>
                          <td className="py-3 px-4 text-center">
                            <Badge className={difficultyBadge.color}>
                              {difficultyBadge.label} ({keyword.difficulty})
                            </Badge>
                          </td>
                          <td className="py-3 px-4 text-center">
                            <div className="flex items-center justify-center gap-1">
                              <TrendingUp className="h-4 w-4 text-success" />
                              <span className="font-semibold">{keyword.opportunity}</span>
                            </div>
                          </td>
                          <td className="py-3 px-4 text-center">
                            {keyword.cpc ? `$${Number(keyword.cpc).toFixed(2)}` : "—"}
                          </td>
                          <td className="py-3 px-4 text-right">
                            {keyword.has_article ? (
                              <Link href={keyword.article_url}>
                                <Button size="sm" variant="outline" className="border-2">
                                  <Eye className="mr-2 h-4 w-4" />
                                  View Article
                                </Button>
                              </Link>
                            ) : (
                              <Link href={keyword.new_article_url}>
                                <Button
                                  size="sm"
                                  className="border-2 shadow-md hover:shadow-lg"
                                  disabled={!auth.user.has_credits}
                                >
                                  <FileText className="mr-2 h-4 w-4" />
                                  Generate Article
                                </Button>
                              </Link>
                            )}
                          </td>
                        </tr>
                      )
                    })}
                  </tbody>
                </table>
              </div>
            )}

            {keywords.length > 0 && (
              <div className="mt-4 text-sm text-muted-foreground text-center">
                Showing top {keywords.length} opportunities. {project.keywords_count > keywords.length && `${project.keywords_count - keywords.length} more available.`}
              </div>
            )}
          </CardContent>
        </Card>
      </div>
    </AppLayout>
  )
}
