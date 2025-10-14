import Navbar from "@/components/marketing/SiteHeader"
import { Card, CardHeader, CardTitle, CardContent, CardFooter } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Link, usePage } from "@inertiajs/react";

export default function Pricing({ plans = [] }) {
  const { routes, auth } = usePage().props;

  // If no plans from backend, show placeholder
  const displayPlans = plans.length ? plans : [
    { id: "free", name: "Free", price: 0, popular: false, features: ["Basic features"] },
    { id: "pro", name: "Pro", price: 10, popular: true, features: ["All features"] },
  ];

  return (
    <div className="bg-glow">
      <Navbar />
      <section className="section-py">
        <div className="container">
          <div className="text-center mb-12">
            <h1 className="font-display text-4xl md:text-6xl font-bold">Simple, transparent pricing</h1>
            <p className="mt-3 text-muted-foreground md:text-lg">Choose the plan that works best for you.</p>
          </div>
          <div className="grid md:grid-cols-3 gap-6">
            {displayPlans.map((p, i) => (
              <Card key={p.id} className="rounded-2xl border-2 hover-lift">
                <CardHeader>
                  <div className="flex items-center justify-between">
                    <CardTitle>{p.name}</CardTitle>
                    {p.popular && <Badge className="bg-accent text-accent-foreground border-2 border-accent/30">Popular</Badge>}
                  </div>
                  <div className="mt-4 text-4xl font-bold">
                    ${p.price}<span className="text-base font-normal text-muted-foreground">/mo</span>
                  </div>
                </CardHeader>
                <CardContent className="text-sm text-muted-foreground space-y-2">
                  {p.features?.map((feature, idx) => (
                    <div key={idx}>✓ {feature}</div>
                  ))}
                </CardContent>
                <CardFooter>
                  {auth?.authenticated ? (
                    <Link href={`${routes.subscribe}?price_id=${p.id}`} className="w-full">
                      <Button className="w-full border-2 shadow-md hover:shadow-lg">Choose plan</Button>
                    </Link>
                  ) : (
                    <Link href={`${routes.signup}?plan=${p.id}`} className="w-full">
                      <Button className="w-full border-2 shadow-md hover:shadow-lg">Get started</Button>
                    </Link>
                  )}
                </CardFooter>
              </Card>
            ))}
          </div>
          {auth?.authenticated && (
            <div className="mt-10 text-center">
              <Link href={routes.billing_portal}><Button variant="outline" className="border-2">Manage billing</Button></Link>
            </div>
          )}
        </div>
      </section>
    </div>
  )
}
