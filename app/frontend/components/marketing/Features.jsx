import { Card, CardHeader, CardTitle, CardContent } from "@/components/ui/card"
export default function Features({ heading = "Features", items = [] }) {
  return (
    <section id="features" className="section-py">
      <div className="container">
        <h2 className="text-3xl md:text-5xl font-display font-bold text-center">{heading}</h2>
        <div className="grid md:grid-cols-3 gap-6 mt-10">
          {items.map((f, idx) => (
            <Card key={idx} className="rounded-2xl border-2 hover-lift">
              <CardHeader className="space-y-2">
                <CardTitle className="flex items-center gap-3">
                  {f.icon ? <span className="shrink-0">{f.icon}</span> : null}
                  <span>{f.title}</span>
                </CardTitle>
              </CardHeader>
              <CardContent className="text-muted-foreground">{f.description}</CardContent>
            </Card>
          ))}
        </div>
      </div>
    </section>
  )
}
