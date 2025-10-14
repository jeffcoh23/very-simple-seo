import { Link, usePage, router } from "@inertiajs/react"
import { Button } from "@/components/ui/button"

export default function Navbar() {
  const { routes, auth } = usePage().props;
  const isAuthenticated = auth?.authenticated;

  const handleLogout = (e) => {
    e.preventDefault();
    router.delete(routes.logout);
  };

  return (
    <header className="sticky top-0 z-40 w-full border-b-2 border-border bg-background/90 backdrop-blur supports-[backdrop-filter]:bg-background/80 shadow-sm">
      <div className="container h-16 flex items-center justify-between">
        <Link
          href={isAuthenticated ? routes.app : routes.home}
          className="font-display text-xl font-bold text-primary tracking-tight hover:text-primary/80 transition-colors"
        >
          VerySimpleSEO
        </Link>

        {isAuthenticated ? (
          // App navigation
          <nav className="flex items-center gap-6">
            <Link
              href={routes.app}
              className="text-sm font-medium text-muted-foreground hover:text-primary transition-colors"
            >
              Dashboard
            </Link>
            <Link
              href={routes.projects}
              className="text-sm font-medium text-muted-foreground hover:text-primary transition-colors"
            >
              Projects
            </Link>
            <Link
              href={routes.pricing}
              className="text-sm font-medium text-muted-foreground hover:text-primary transition-colors"
            >
              Pricing
            </Link>
            <Button
              type="button"
              variant="outline"
              className="border-2"
              onClick={handleLogout}
            >
              Logout
            </Button>
          </nav>
        ) : (
          // Marketing navigation
          <>
            <nav className="hidden md:flex items-center gap-6 text-sm font-medium">
              <Link href="/#features" className="text-muted-foreground hover:text-primary transition-colors">
                Features
              </Link>
              <Link href={routes.pricing} className="text-muted-foreground hover:text-primary transition-colors">
                Pricing
              </Link>
              <Link href="/#faq" className="text-muted-foreground hover:text-primary transition-colors">
                FAQ
              </Link>
            </nav>
            <div className="flex items-center gap-2">
              <Link href={routes.login}>
                <Button variant="ghost">Log in</Button>
              </Link>
              <Link href={routes.signup}>
                <Button className="border-2 shadow-md hover:shadow-lg">Get started</Button>
              </Link>
            </div>
          </>
        )}
      </div>
    </header>
  )
}
