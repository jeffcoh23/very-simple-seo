import { useState } from "react"
import { Link, usePage, router } from "@inertiajs/react"
import { Button } from "@/components/ui/button"
import { Menu, X, Settings } from "lucide-react"

export default function Navbar() {
  const { routes, auth } = usePage().props;
  const isAuthenticated = auth?.authenticated;
  const [isMobileMenuOpen, setIsMobileMenuOpen] = useState(false);

  const handleLogout = (e) => {
    e.preventDefault();
    router.delete(routes.logout);
  };

  const closeMobileMenu = () => {
    setIsMobileMenuOpen(false);
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
          <>
            <nav className="hidden md:flex items-center gap-6">
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
              <Link
                href={routes.settings}
                className="text-sm font-medium text-muted-foreground hover:text-primary transition-colors"
              >
                Settings
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

            {/* Mobile menu toggle */}
            <Button
              variant="ghost"
              size="icon"
              className="md:hidden"
              onClick={() => setIsMobileMenuOpen(!isMobileMenuOpen)}
            >
              {isMobileMenuOpen ? <X className="h-6 w-6" /> : <Menu className="h-6 w-6" />}
            </Button>
          </>
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
            <div className="hidden md:flex items-center gap-2">
              <Link href={routes.login}>
                <Button variant="ghost">Log in</Button>
              </Link>
              <Link href={routes.signup}>
                <Button className="border-2 shadow-md hover:shadow-lg">Get started</Button>
              </Link>
            </div>

            {/* Mobile menu toggle for unauthenticated */}
            <Button
              variant="ghost"
              size="icon"
              className="md:hidden"
              onClick={() => setIsMobileMenuOpen(!isMobileMenuOpen)}
            >
              {isMobileMenuOpen ? <X className="h-6 w-6" /> : <Menu className="h-6 w-6" />}
            </Button>
          </>
        )}
      </div>

      {/* Mobile Menu Dropdown */}
      {isMobileMenuOpen && (
        <div className="md:hidden bg-background border-b-2 border-border">
          <nav className="flex flex-col p-4 space-y-2">
            {isAuthenticated ? (
              <>
                <Link
                  href={routes.app}
                  className="text-sm font-medium p-3 hover:bg-primary/5 rounded-lg transition-colors"
                  onClick={closeMobileMenu}
                >
                  Dashboard
                </Link>
                <Link
                  href={routes.projects}
                  className="text-sm font-medium p-3 hover:bg-primary/5 rounded-lg transition-colors"
                  onClick={closeMobileMenu}
                >
                  Projects
                </Link>
                <Link
                  href={routes.pricing}
                  className="text-sm font-medium p-3 hover:bg-primary/5 rounded-lg transition-colors"
                  onClick={closeMobileMenu}
                >
                  Pricing
                </Link>
                <Link
                  href={routes.settings}
                  className="text-sm font-medium p-3 hover:bg-primary/5 rounded-lg transition-colors flex items-center gap-2"
                  onClick={closeMobileMenu}
                >
                  <Settings className="h-4 w-4" />
                  Settings
                </Link>
                <div className="pt-2">
                  <Button
                    type="button"
                    variant="outline"
                    className="w-full border-2"
                    onClick={(e) => {
                      closeMobileMenu();
                      handleLogout(e);
                    }}
                  >
                    Logout
                  </Button>
                </div>
              </>
            ) : (
              <>
                <Link
                  href="/#features"
                  className="text-sm font-medium p-3 hover:bg-primary/5 rounded-lg transition-colors"
                  onClick={closeMobileMenu}
                >
                  Features
                </Link>
                <Link
                  href={routes.pricing}
                  className="text-sm font-medium p-3 hover:bg-primary/5 rounded-lg transition-colors"
                  onClick={closeMobileMenu}
                >
                  Pricing
                </Link>
                <Link
                  href="/#faq"
                  className="text-sm font-medium p-3 hover:bg-primary/5 rounded-lg transition-colors"
                  onClick={closeMobileMenu}
                >
                  FAQ
                </Link>
                <div className="pt-2 flex flex-col gap-2">
                  <Link href={routes.login} onClick={closeMobileMenu}>
                    <Button variant="ghost" className="w-full">
                      Log in
                    </Button>
                  </Link>
                  <Link href={routes.signup} onClick={closeMobileMenu}>
                    <Button className="w-full border-2 shadow-md hover:shadow-lg">
                      Get started
                    </Button>
                  </Link>
                </div>
              </>
            )}
          </nav>
        </div>
      )}
    </header>
  )
}
