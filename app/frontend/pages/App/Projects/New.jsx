import { usePage, router } from "@inertiajs/react"
import AppLayout from "@/layout/AppLayout"
import { Button } from "@/components/ui/button"
import { ArrowLeft } from "lucide-react"
import { Link } from "@inertiajs/react"
import ProjectForm from "@/components/app/ProjectForm"

export default function ProjectsNew() {
  const { routes } = usePage().props

  const handleSubmit = (data) => {
    router.post(routes.create_project, data)
  }

  return (
    <AppLayout>
      <div className="max-w-4xl mx-auto space-y-6">
        {/* Header */}
        <div>
          <Link href={routes.projects} className="inline-flex items-center text-sm text-muted-foreground hover:text-foreground mb-4">
            <ArrowLeft className="mr-2 h-4 w-4" />
            Back to Projects
          </Link>
          <h1 className="text-3xl font-display font-bold">Create New Project</h1>
          <p className="text-muted-foreground mt-1">
            Set up a new SEO content project with organized sections
          </p>
        </div>

        {/* Shared Project Form */}
        <ProjectForm
          mode="create"
          onSubmit={handleSubmit}
          onAutofill={true}
          submitButtonText="Create Project"
          showButtons={false}
        />

        {/* Action Buttons */}
        <div className="flex items-center justify-between pt-6 border-t-2">
          <Link href={routes.projects}>
            <Button type="button" variant="outline" className="border-2">
              Cancel
            </Button>
          </Link>
          <Button
            type="submit"
            form="project-form"
            className="border-2 shadow-md hover:shadow-lg"
          >
            Create Project
          </Button>
        </div>
      </div>
    </AppLayout>
  )
}
