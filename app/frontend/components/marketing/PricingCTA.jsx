import { Link } from "@inertiajs/react"
import { Button } from "@/components/ui/button"
export default function PricingCTA({ title, subtitle, cta }) {
  return (
    <section className="py-16 text-center border-t-2">
      <div className="container">
        <h2 className="text-3xl md:text-4xl font-display font-bold">{title}</h2>
        {subtitle && <p className="mt-2 text-muted-foreground md:text-lg">{subtitle}</p>}
        {cta && (
          <div className="mt-6">
            <Link href={cta.href}><Button size="lg" className="border-2 shadow-md hover:shadow-lg">{cta.label}</Button></Link>
          </div>
        )}
      </div>
    </section>
  )
}
