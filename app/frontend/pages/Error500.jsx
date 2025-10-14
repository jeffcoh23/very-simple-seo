import { Link, usePage } from "@inertiajs/react"
import { Button } from "@/components/ui/button"

export default function Error500() {
  const { routes } = usePage().props;

  return (
    <div className="min-h-screen flex items-center justify-center bg-background">
      <div className="text-center space-y-4">
        <h1 className="text-9xl font-display font-bold text-muted-foreground">500</h1>
        <h2 className="text-2xl font-semibold">Something went wrong</h2>
        <p className="text-muted-foreground">We're working to fix the issue.</p>
        <div className="pt-4">
          <Link href={routes.home}>
            <Button>Go home</Button>
          </Link>
        </div>
      </div>
    </div>
  )
}
