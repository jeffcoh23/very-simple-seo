import { Card, CardContent } from "@/components/ui/card"
export default function SocialProof({ logos = [] }) {
  return (
    <section className="py-10 bg-muted/30">
      <div className="container grid grid-cols-2 sm:grid-cols-3 md:grid-cols-6 gap-6 opacity-80">
        {logos.map((logo, i) => (
          <Card key={i} className="border-dashed">
            <CardContent className="p-4 text-center text-sm text-muted-foreground">
              {logo?.src
                ? <img src={logo.src} alt={logo.alt || logo.label || `logo-${i}`} className="mx-auto h-8 object-contain" />
                : <span>{logo.label || "Your Logo"}</span>}
            </CardContent>
          </Card>
        ))}
      </div>
    </section>
  )
}
