import { Link, usePage } from "@inertiajs/react"
import AppLayout from "@/layout/AppLayout"
import { Button } from "@/components/ui/button"
import { Card, CardHeader, CardTitle, CardDescription, CardContent } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { Tabs, TabsList, TabsTrigger, TabsContent } from "@/components/ui/tabs"
import { ArrowLeft, FileText, Key } from "lucide-react"

export default function ProjectsArticles() {
  const { project, articles } = usePage().props
  const { auth } = usePage().props

  const formatDate = (dateString) => {
    const date = new Date(dateString)
    return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' })
  }

  const getStatusBadge = (status) => {
    const badges = {
      pending: <Badge className="bg-warning-soft text-warning border-2 border-warning/30 font-semibold">Pending</Badge>,
      generating: <Badge className="bg-info-soft text-info border-2 border-info/30 font-semibold">Generating</Badge>,
      completed: <Badge className="bg-success-soft text-success border-2 border-success/30 font-semibold">Completed</Badge>,
      failed: <Badge className="bg-destructive-soft text-destructive border-2 border-destructive/30 font-semibold">Failed</Badge>
    }
    return badges[status] || null
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

        {/* Tabs */}
        <Tabs value="articles" className="w-full">
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

          <TabsContent value="articles">
            <Card className="border-2">
              <CardHeader>
                <CardTitle>Articles</CardTitle>
                <CardDescription>
                  Content generated from your keywords
                </CardDescription>
              </CardHeader>
              <CardContent>
                {articles.length === 0 ? (
                  <div className="text-center py-12 text-muted-foreground">
                    <p>No articles yet. Generate articles from your keywords above.</p>
                  </div>
                ) : (
                  <div className="space-y-4">
                    {articles.map((article) => (
                      <Link
                        key={article.id}
                        href={article.article_url}
                        className="flex items-center justify-between p-4 border-2 rounded-lg hover:bg-muted/50 transition-colors"
                      >
                        <div className="flex-1">
                          <div className="flex items-center gap-2 mb-1">
                            <h3 className="font-semibold">{article.title || "Untitled"}</h3>
                            {getStatusBadge(article.status)}
                          </div>
                          <p className="text-sm text-muted-foreground font-mono">
                            {article.keyword}
                          </p>
                        </div>
                        <div className="flex items-center gap-6 text-sm">
                          {article.word_count > 0 && (
                            <div className="text-center">
                              <div className="font-semibold">{article.word_count}</div>
                              <div className="text-muted-foreground">Words</div>
                            </div>
                          )}
                          <div className="text-muted-foreground">
                            {formatDate(article.created_at)}
                          </div>
                        </div>
                      </Link>
                    ))}
                  </div>
                )}

                {articles.length > 0 && project.articles_count > articles.length && (
                  <div className="mt-4 text-sm text-muted-foreground text-center">
                    Showing {articles.length} of {project.articles_count} articles.
                  </div>
                )}
              </CardContent>
            </Card>
          </TabsContent>
        </Tabs>
      </div>
    </AppLayout>
  )
}
