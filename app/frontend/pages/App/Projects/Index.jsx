import { Link, usePage } from "@inertiajs/react"
import AppLayout from "@/layout/AppLayout"
import { Button } from "@/components/ui/button"
import { Card, CardHeader, CardTitle, CardDescription, CardContent, CardFooter } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { PlusCircle, FileText, Key, TrendingUp } from "lucide-react"

export default function ProjectsIndex() {
  const { projects } = usePage().props
  const { routes } = usePage().props

  return (
    <AppLayout>
      <div className="space-y-6">
        {/* Header */}
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-3xl font-display font-bold">Projects</h1>
            <p className="text-muted-foreground mt-1">
              Manage your SEO content projects
            </p>
          </div>
          <Link href={routes.new_project}>
            <Button>
              <PlusCircle className="mr-2 h-4 w-4" />
              New Project
            </Button>
          </Link>
        </div>

        {/* Projects Grid */}
        {projects.length === 0 ? (
          <Card>
            <CardContent className="py-12 text-center">
              <div className="flex flex-col items-center gap-4">
                <div className="rounded-full bg-muted p-4">
                  <FileText className="h-8 w-8 text-muted-foreground" />
                </div>
                <div>
                  <h3 className="text-lg font-semibold">No projects yet</h3>
                  <p className="text-sm text-muted-foreground mt-1">
                    Get started by creating your first project
                  </p>
                </div>
                <Link href={routes.new_project}>
                  <Button>
                    <PlusCircle className="mr-2 h-4 w-4" />
                    Create Project
                  </Button>
                </Link>
              </div>
            </CardContent>
          </Card>
        ) : (
          <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
            {projects.map((project) => (
              <Card key={project.id} className="hover:shadow-md transition-shadow">
                <CardHeader>
                  <div className="flex items-start justify-between">
                    <div className="flex-1">
                      <CardTitle className="text-xl mb-1">{project.name}</CardTitle>
                      {project.domain && (
                        <CardDescription className="break-all">
                          {project.domain}
                        </CardDescription>
                      )}
                    </div>
                  </div>
                </CardHeader>
                <CardContent className="space-y-3">
                  {/* Stats */}
                  <div className="grid grid-cols-3 gap-2 text-center">
                    <div className="rounded-lg bg-muted/50 p-2">
                      <div className="text-2xl font-bold">{project.keywords_count}</div>
                      <div className="text-xs text-muted-foreground flex items-center justify-center gap-1">
                        <Key className="h-3 w-3" />
                        Keywords
                      </div>
                    </div>
                    <div className="rounded-lg bg-muted/50 p-2">
                      <div className="text-2xl font-bold">{project.articles_count}</div>
                      <div className="text-xs text-muted-foreground flex items-center justify-center gap-1">
                        <FileText className="h-3 w-3" />
                        Articles
                      </div>
                    </div>
                    <div className="rounded-lg bg-muted/50 p-2">
                      <div className="text-2xl font-bold">{project.competitors_count}</div>
                      <div className="text-xs text-muted-foreground flex items-center justify-center gap-1">
                        <TrendingUp className="h-3 w-3" />
                        Competitors
                      </div>
                    </div>
                  </div>

                  {/* Metadata */}
                  {project.niche && (
                    <div className="flex items-center gap-2">
                      <Badge variant="secondary">{project.niche}</Badge>
                    </div>
                  )}
                </CardContent>
                <CardFooter className="flex gap-2">
                  <Link href={`/projects/${project.id}`} className="flex-1">
                    <Button variant="default" className="w-full">
                      View Project
                    </Button>
                  </Link>
                  <Link href={`/projects/${project.id}/edit`}>
                    <Button variant="outline" size="icon">
                      <svg
                        xmlns="http://www.w3.org/2000/svg"
                        width="16"
                        height="16"
                        viewBox="0 0 24 24"
                        fill="none"
                        stroke="currentColor"
                        strokeWidth="2"
                        strokeLinecap="round"
                        strokeLinejoin="round"
                      >
                        <path d="M17 3a2.85 2.83 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5Z" />
                        <path d="m15 5 4 4" />
                      </svg>
                    </Button>
                  </Link>
                </CardFooter>
              </Card>
            ))}
          </div>
        )}
      </div>
    </AppLayout>
  )
}
