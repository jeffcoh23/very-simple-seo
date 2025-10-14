import { Link, usePage } from "@inertiajs/react"
import AppLayout from "@/layout/AppLayout"
import { Button } from "@/components/ui/button"
import { Card, CardHeader, CardTitle, CardDescription, CardContent } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { PlusCircle, FileText, Key, TrendingUp, Clock } from "lucide-react"

export default function Dashboard() {
  const { recent_projects, recent_articles, stats } = usePage().props
  const { routes, auth } = usePage().props

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
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-3xl font-display font-bold">Dashboard</h1>
            <p className="text-muted-foreground mt-1">
              Welcome back, {auth.user.first_name || auth.user.email_address}
            </p>
          </div>
          <Link href={routes.new_project}>
            <Button className="border-2 shadow-md hover:shadow-lg">
              <PlusCircle className="mr-2 h-4 w-4" />
              New Project
            </Button>
          </Link>
        </div>

        {/* Stats Grid */}
        <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
          <Card className="border-2">
            <CardContent className="pt-6">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm font-medium text-muted-foreground">Projects</p>
                  <p className="text-2xl font-bold">{stats.total_projects}</p>
                </div>
                <FileText className="h-8 w-8 text-muted-foreground" />
              </div>
            </CardContent>
          </Card>

          <Card className="border-2">
            <CardContent className="pt-6">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm font-medium text-muted-foreground">Keywords</p>
                  <p className="text-2xl font-bold">{stats.total_keywords}</p>
                </div>
                <Key className="h-8 w-8 text-muted-foreground" />
              </div>
            </CardContent>
          </Card>

          <Card className="border-2">
            <CardContent className="pt-6">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm font-medium text-muted-foreground">Articles</p>
                  <p className="text-2xl font-bold">{stats.total_articles}</p>
                </div>
                <TrendingUp className="h-8 w-8 text-muted-foreground" />
              </div>
            </CardContent>
          </Card>

          <Card className="border-2">
            <CardContent className="pt-6">
              <div className="flex items-center justify-between">
                <div>
                  <p className="text-sm font-medium text-muted-foreground">Credits</p>
                  <p className="text-2xl font-bold">{stats.credits_remaining}</p>
                </div>
                <Clock className="h-8 w-8 text-muted-foreground" />
              </div>
              {stats.credits_remaining === 0 && (
                <Link href={routes.pricing} className="text-sm text-primary hover:underline mt-2 inline-block">
                  Get more credits →
                </Link>
              )}
            </CardContent>
          </Card>
        </div>

        {/* Recent Projects */}
        <Card className="border-2">
          <CardHeader>
            <div className="flex items-center justify-between">
              <div>
                <CardTitle>Recent Projects</CardTitle>
                <CardDescription>Your latest SEO content projects</CardDescription>
              </div>
              <Link href={routes.projects}>
                <Button variant="ghost" size="sm" className="hover:text-primary">View all</Button>
              </Link>
            </div>
          </CardHeader>
          <CardContent>
            {recent_projects.length === 0 ? (
              <div className="text-center py-8">
                <p className="text-muted-foreground mb-4">No projects yet</p>
                <Link href={routes.new_project}>
                  <Button className="border-2 shadow-md hover:shadow-lg">
                    <PlusCircle className="mr-2 h-4 w-4" />
                    Create Your First Project
                  </Button>
                </Link>
              </div>
            ) : (
              <div className="space-y-4">
                {recent_projects.map((project) => (
                  <Link
                    key={project.id}
                    href={`/projects/${project.id}`}
                    className="flex items-center justify-between p-4 border-2 rounded-lg hover:bg-muted/50 transition-colors"
                  >
                    <div className="flex-1">
                      <h3 className="font-semibold">{project.name}</h3>
                      <p className="text-sm text-muted-foreground">{project.domain}</p>
                    </div>
                    <div className="flex items-center gap-6 text-sm">
                      <div className="text-center">
                        <div className="font-semibold">{project.keywords_count}</div>
                        <div className="text-muted-foreground">Keywords</div>
                      </div>
                      <div className="text-center">
                        <div className="font-semibold">{project.articles_count}</div>
                        <div className="text-muted-foreground">Articles</div>
                      </div>
                      <div className="text-muted-foreground">
                        {formatDate(project.created_at)}
                      </div>
                    </div>
                  </Link>
                ))}
              </div>
            )}
          </CardContent>
        </Card>

        {/* Recent Articles */}
        <Card className="border-2">
          <CardHeader>
            <CardTitle>Recent Articles</CardTitle>
            <CardDescription>Your latest generated content</CardDescription>
          </CardHeader>
          <CardContent>
            {recent_articles.length === 0 ? (
              <div className="text-center py-8">
                <p className="text-muted-foreground">No articles yet</p>
              </div>
            ) : (
              <div className="space-y-4">
                {recent_articles.map((article) => (
                  <Link
                    key={article.id}
                    href={`/articles/${article.id}`}
                    className="flex items-center justify-between p-4 border-2 rounded-lg hover:bg-muted/50 transition-colors"
                  >
                    <div className="flex-1">
                      <div className="flex items-center gap-2 mb-1">
                        <h3 className="font-semibold">{article.title || "Untitled"}</h3>
                        {getStatusBadge(article.status)}
                      </div>
                      <p className="text-sm text-muted-foreground">
                        {article.project_name} · {article.keyword}
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
          </CardContent>
        </Card>
      </div>
    </AppLayout>
  )
}
