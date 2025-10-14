import { usePage, router } from "@inertiajs/react"
import AppLayout from "@/layout/AppLayout"
import { Button } from "@/components/ui/button"
import { ArrowLeft, Trash2 } from "lucide-react"
import { Link } from "@inertiajs/react"
import { useState } from "react"
import ProjectForm from "@/components/app/ProjectForm"

export default function ProjectsEdit() {
  const { project } = usePage().props
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false)

  const handleSubmit = (data) => {
    router.put(project.routes.update_project, data)
  }

  const handleDelete = () => {
    if (showDeleteConfirm) {
      router.delete(project.routes.delete_project)
    } else {
      setShowDeleteConfirm(true)
      setTimeout(() => setShowDeleteConfirm(false), 3000)
    }
  }

  return (
    <AppLayout>
      <div className="max-w-4xl mx-auto space-y-6">
        {/* Header */}
        <div>
          <Link href={project.routes.project} className="inline-flex items-center text-sm text-muted-foreground hover:text-foreground mb-4">
            <ArrowLeft className="mr-2 h-4 w-4" />
            Back to Project
          </Link>
          <h1 className="text-3xl font-display font-bold">Edit Project</h1>
          <p className="text-muted-foreground mt-1">
            Update your project details in organized sections
          </p>
        </div>

        {/* Shared Project Form */}
        <ProjectForm
          project={project}
          mode="edit"
          onSubmit={handleSubmit}
          submitButtonText="Save Changes"
          showButtons={false}
        />

        {/* Action Buttons */}
        <div className="flex items-center justify-between pt-6 border-t-2">
          <Button
            type="button"
            variant={showDeleteConfirm ? "destructive" : "outline"}
            className="border-2"
            onClick={handleDelete}
          >
            <Trash2 className="mr-2 h-4 w-4" />
            {showDeleteConfirm ? "Click again to confirm" : "Delete Project"}
          </Button>
          <div className="flex items-center gap-3">
            <Link href={project.routes.project}>
              <Button type="button" variant="outline" className="border-2">
                Cancel
              </Button>
            </Link>
            <Button
              type="submit"
              form="project-form"
              className="border-2 shadow-md hover:shadow-lg"
            >
              Save Changes
            </Button>
          </div>
        </div>
      </div>
    </AppLayout>
  )
}
