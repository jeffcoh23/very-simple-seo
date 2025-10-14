import { Link } from "@inertiajs/react"
import { Button } from "@/components/ui/button"
import { ArrowRight, Play } from "lucide-react"

export default function Hero({ title, subtitle, primaryCta, secondaryCta }) {
  return (
    <section className="section-py bg-hero">
      <div className="container grid gap-10 lg:grid-cols-2 lg:gap-12 items-center">
        <div className="flex flex-col justify-center space-y-6">
          <h1 className="font-display text-4xl sm:text-5xl lg:text-6xl font-bold tracking-tight">{title}</h1>
          <p className="text-muted-foreground md:text-xl max-w-[600px]">{subtitle}</p>
          <div className="flex flex-col sm:flex-row gap-3 pt-2">
            {primaryCta && (
              <Link href={primaryCta.href}>
                <Button size="lg" className="font-medium border-2 shadow-md hover:shadow-lg">
                  {primaryCta.label} <ArrowRight className="ml-2 h-4 w-4" />
                </Button>
              </Link>
            )}
            {secondaryCta && (
              <Link href={secondaryCta.href}>
                <Button size="lg" variant="outline" className="font-medium border-2 shadow-md hover:shadow-lg">
                  <Play className="mr-2 h-4 w-4" /> {secondaryCta.label}
                </Button>
              </Link>
            )}
          </div>
        </div>
        <div className="relative lg:ml-auto">
          <div className="relative w-full aspect-video overflow-hidden rounded-2xl shadow-2xl rotate-2">
            <img src="/placeholder.png" alt="Product preview" className="object-cover w-full h-full" />
          </div>
          <div className="absolute -bottom-6 -left-6 w-24 h-24 bg-gradient-to-r from-primary via-accent to-primary rounded-full blur-xl opacity-50"></div>
          <div className="absolute -top-6 -right-6 w-24 h-24 bg-gradient-to-r from-accent via-primary to-accent rounded-full blur-xl opacity-50"></div>
        </div>
      </div>
    </section>
  )
}
