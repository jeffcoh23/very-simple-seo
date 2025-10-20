import { useEffect, useState, useRef, useMemo } from "react"
import { Link, usePage, router } from "@inertiajs/react"
import { createConsumer } from "@rails/actioncable"
import AppLayout from "@/layout/AppLayout"
import { Button } from "@/components/ui/button"
import { Card, CardHeader, CardTitle, CardDescription, CardContent } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { Tabs, TabsList, TabsTrigger, TabsContent } from "@/components/ui/tabs"
import { ArrowLeft, Loader2, TrendingUp, Eye, Star, FileText, ChevronDown, ChevronUp, Filter, X, Key } from "lucide-react"

export default function ProjectsKeywords() {
  const { project, keywordResearch, keywords, view, stats } = usePage().props
  const { auth } = usePage().props

  const [researchStatus, setResearchStatus] = useState(keywordResearch?.status)
  const [keywordsFound, setKeywordsFound] = useState(keywordResearch?.total_keywords_found || 0)
  const [progressMessage, setProgressMessage] = useState("")
  const [progressLog, setProgressLog] = useState(keywordResearch?.progress_log || [])
  const [showResearchLog, setShowResearchLog] = useState(false)
  const progressLogRef = useRef(null)

  // Filter and sort state
  const [intentFilter, setIntentFilter] = useState("all")
  const [difficultyFilter, setDifficultyFilter] = useState("all")
  const [sortBy, setSortBy] = useState("opportunity")
  const [expandedClusters, setExpandedClusters] = useState(new Set())

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

          if (data.progress_message) {
            setProgressMessage(data.progress_message)
          }

          if (data.progress_log) {
            setProgressLog(data.progress_log)
          }

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

  const formatDate = (dateString) => {
    const date = new Date(dateString)
    return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })
  }

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

  // Filter and sort keywords
  const filteredAndSortedKeywords = useMemo(() => {
    let result = [...keywords]

    // Apply intent filter
    if (intentFilter !== "all") {
      result = result.filter(k => k.intent === intentFilter)
    }

    // Apply difficulty filter
    if (difficultyFilter !== "all") {
      result = result.filter(k => {
        const diff = getDifficultyBadge(k.difficulty).label.toLowerCase()
        return diff === difficultyFilter
      })
    }

    // Apply sorting
    result.sort((a, b) => {
      switch (sortBy) {
        case "volume":
          return (b.volume || 0) - (a.volume || 0)
        case "difficulty":
          return a.difficulty - b.difficulty
        case "cpc":
          return (b.cpc || 0) - (a.cpc || 0)
        case "keyword":
          return a.keyword.localeCompare(b.keyword)
        case "opportunity":
        default:
          return b.opportunity - a.opportunity
      }
    })

    return result
  }, [keywords, intentFilter, difficultyFilter, sortBy])

  // Count active filters
  const activeFiltersCount = (intentFilter !== "all" ? 1 : 0) + (difficultyFilter !== "all" ? 1 : 0)

  const clearFilters = () => {
    setIntentFilter("all")
    setDifficultyFilter("all")
  }

  // Toggle cluster view
  const toggleView = () => {
    const newView = view === "representatives" ? "all" : "representatives"
    router.visit(project.routes.keywords + `?view=${newView}`, {
      preserveState: true,
      preserveScroll: true
    })
  }

  // Toggle cluster expansion
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

  return (
    <AppLayout>
      <div className="space-y-6">
        {/* Header */}
        <div>
          <Link href={project.routes.project} className="inline-flex items-center text-sm text-muted-foreground hover:text-primary transition-colors mb-4">
            <ArrowLeft className="mr-2 h-4 w-4" />
            Back to Project
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

                  {progressLog.length > 0 && (
                    <div
                      ref={progressLogRef}
                      className="mt-3 space-y-1 max-h-48 overflow-y-auto bg-white/50 rounded p-2 border-2 border-info/30 scroll-smooth"
                    >
                      {progressLog.map((entry, index) => {
                        const indent = entry.indent || 0
                        const paddingLeft = indent * 16
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

        {/* Research Log (Expandable) */}
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

        {/* Tabs */}
        <Tabs value="keywords" className="w-full">
          <TabsList className="border-2">
            <TabsTrigger value="keywords" asChild>
              <Link href={project.routes.keywords} className="flex items-center gap-2">
                <Key className="h-4 w-4" />
                Keywords ({project.keywords_count})
              </Link>
            </TabsTrigger>
            <TabsTrigger value="articles" asChild>
              <Link href={project.routes.articles} className="flex items-center gap-2">
                <FileText className="h-4 w-4" />
                Articles ({project.articles_count})
              </Link>
            </TabsTrigger>
          </TabsList>

          <TabsContent value="keywords">
            <Card className="border-2">
              <CardHeader>
                <div className="flex items-center justify-between">
                  <div>
                    <CardTitle>Keywords</CardTitle>
                    <CardDescription>
                      Top keyword opportunities for your content strategy
                    </CardDescription>
                  </div>
                  <div className="flex items-center gap-2">
                    {/* Cluster View Toggle */}
                    {stats && stats.cluster_representatives > 0 && (
                      <Button
                        variant={view === "representatives" ? "default" : "outline"}
                        size="sm"
                        onClick={toggleView}
                        className="border-2"
                      >
                        {view === "representatives" ? (
                          <>
                            <ChevronDown className="h-4 w-4 mr-2" />
                            Representatives ({stats.cluster_representatives + stats.unclustered})
                          </>
                        ) : (
                          <>
                            <ChevronUp className="h-4 w-4 mr-2" />
                            All Variations ({stats.total_keywords})
                          </>
                        )}
                      </Button>
                    )}
                    {activeFiltersCount > 0 && (
                      <Button variant="outline" size="sm" onClick={clearFilters} className="border-2">
                        <X className="h-4 w-4 mr-2" />
                        Clear {activeFiltersCount} filter{activeFiltersCount > 1 ? 's' : ''}
                      </Button>
                    )}
                  </div>
                </div>
              </CardHeader>
              <CardContent>
                {keywords.length === 0 ? (
                  <div className="text-center py-12 text-muted-foreground">
                    <p>No keywords found yet. Research is in progress...</p>
                  </div>
                ) : (
                  <>
                    {/* Filter Controls */}
                    <div className="flex flex-col sm:flex-row gap-3 mb-6 p-4 bg-muted/30 rounded-lg border-2">
                      <div className="flex items-center gap-2">
                        <Filter className="h-4 w-4 text-muted-foreground" />
                        <span className="text-sm font-semibold text-muted-foreground">Filters:</span>
                      </div>

                      {/* Intent Filter */}
                      <div className="flex flex-wrap gap-2">
                        <Button
                          size="sm"
                          variant={intentFilter === "all" ? "default" : "outline"}
                          onClick={() => setIntentFilter("all")}
                          className="border-2"
                        >
                          All Intent
                        </Button>
                        <Button
                          size="sm"
                          variant={intentFilter === "informational" ? "default" : "outline"}
                          onClick={() => setIntentFilter("informational")}
                          className="border-2"
                        >
                          Informational
                        </Button>
                        <Button
                          size="sm"
                          variant={intentFilter === "commercial" ? "default" : "outline"}
                          onClick={() => setIntentFilter("commercial")}
                          className="border-2"
                        >
                          Commercial
                        </Button>
                        <Button
                          size="sm"
                          variant={intentFilter === "transactional" ? "default" : "outline"}
                          onClick={() => setIntentFilter("transactional")}
                          className="border-2"
                        >
                          Transactional
                        </Button>
                      </div>

                      {/* Difficulty Filter */}
                      <div className="flex flex-wrap gap-2">
                        <Button
                          size="sm"
                          variant={difficultyFilter === "all" ? "default" : "outline"}
                          onClick={() => setDifficultyFilter("all")}
                          className="border-2"
                        >
                          All Difficulty
                        </Button>
                        <Button
                          size="sm"
                          variant={difficultyFilter === "easy" ? "default" : "outline"}
                          onClick={() => setDifficultyFilter("easy")}
                          className="border-2"
                        >
                          Easy
                        </Button>
                        <Button
                          size="sm"
                          variant={difficultyFilter === "medium" ? "default" : "outline"}
                          onClick={() => setDifficultyFilter("medium")}
                          className="border-2"
                        >
                          Medium
                        </Button>
                        <Button
                          size="sm"
                          variant={difficultyFilter === "hard" ? "default" : "outline"}
                          onClick={() => setDifficultyFilter("hard")}
                          className="border-2"
                        >
                          Hard
                        </Button>
                      </div>

                      {/* Sort By */}
                      <div className="flex items-center gap-2 sm:ml-auto">
                        <span className="text-sm font-semibold text-muted-foreground">Sort:</span>
                        <select
                          value={sortBy}
                          onChange={(e) => setSortBy(e.target.value)}
                          className="border-2 border-border rounded-lg px-3 py-1.5 text-sm bg-background"
                        >
                          <option value="opportunity">Opportunity</option>
                          <option value="volume">Volume</option>
                          <option value="difficulty">Difficulty</option>
                          <option value="cpc">CPC</option>
                          <option value="keyword">Keyword A-Z</option>
                        </select>
                      </div>
                    </div>

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
                          {filteredAndSortedKeywords.map((keyword) => {
                            const difficultyBadge = getDifficultyBadge(keyword.difficulty)
                            const isClusterRep = keyword.cluster_id && keyword.is_cluster_representative
                            const hasClusterSiblings = isClusterRep && keyword.cluster_keywords && keyword.cluster_keywords.length > 0
                            const isExpanded = expandedClusters.has(keyword.cluster_id)

                            return (
                              <>
                                <tr
                                  key={keyword.id}
                                  className={`border-b-2 hover:bg-muted/50 transition-colors ${hasClusterSiblings ? 'cursor-pointer' : ''}`}
                                  onClick={hasClusterSiblings ? () => toggleCluster(keyword.cluster_id) : undefined}
                                >
                                  <td className="py-3 px-4">
                                    <div className="flex items-center gap-2">
                                      {hasClusterSiblings && (
                                        isExpanded ? (
                                          <ChevronUp className="h-4 w-4 text-muted-foreground flex-shrink-0" />
                                        ) : (
                                          <ChevronDown className="h-4 w-4 text-muted-foreground flex-shrink-0" />
                                        )
                                      )}
                                      {keyword.starred && (
                                        <Star className="h-4 w-4 fill-accent text-accent" />
                                      )}
                                      <span className="font-medium">{keyword.keyword}</span>
                                      {isClusterRep && keyword.cluster_size > 1 && (
                                        <Badge variant="outline" className="text-xs border-primary/30 text-primary">
                                          +{keyword.cluster_size - 1} variation{keyword.cluster_size - 1 !== 1 ? 's' : ''}
                                        </Badge>
                                      )}
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
                                  <td className="py-3 px-4 text-right" onClick={(e) => e.stopPropagation()}>
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

                                {/* Cluster siblings (expanded) */}
                                {isExpanded && hasClusterSiblings && keyword.cluster_keywords.map((siblingText, idx) => (
                                  <tr key={`${keyword.id}-sibling-${idx}`} className="border-b bg-muted/30">
                                    <td className="py-2 px-4 pl-12">
                                      <div className="flex items-center gap-2">
                                        <span className="text-sm text-muted-foreground font-mono">{siblingText}</span>
                                        <Badge variant="outline" className="text-xs">variation</Badge>
                                      </div>
                                    </td>
                                    <td colSpan="6" className="py-2 px-4 text-sm text-muted-foreground">
                                      Similar to representative keyword
                                    </td>
                                  </tr>
                                ))}
                              </>
                            )
                          })}
                        </tbody>
                      </table>
                    </div>

                    {filteredAndSortedKeywords.length > 0 && (
                      <div className="mt-4 text-sm text-muted-foreground text-center">
                        Showing {filteredAndSortedKeywords.length} keyword{filteredAndSortedKeywords.length !== 1 ? 's' : ''} {filteredAndSortedKeywords.length < keywords.length && `of ${keywords.length} total`}
                      </div>
                    )}
                  </>
                )}
              </CardContent>
            </Card>
          </TabsContent>
        </Tabs>
      </div>
    </AppLayout>
  )
}
