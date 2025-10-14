import Navbar from "@/components/marketing/SiteHeader"
import Hero from "@/components/marketing/Hero"
import SocialProof from "@/components/marketing/SocialProof"
import Features from "@/components/marketing/Features"
import PricingCTA from "@/components/marketing/PricingCTA"
import FAQ from "@/components/marketing/FAQ"
import Footer from "@/components/marketing/Footer"
import { CheckCircle2, CreditCard, Zap } from "lucide-react"
import { usePage } from "@inertiajs/react"

export default function Home() {
  const { routes, auth } = usePage().props;
  const isAuthenticated = auth?.authenticated;

  const hero = {
    title: "Ship your SaaS faster than ever",
    subtitle: "Rails 8 + Inertia React + Stripe billing. Everything you need to validate and launch.",
    primaryCta: {
      label: isAuthenticated ? "Go to Dashboard" : "Get started",
      href: isAuthenticated ? routes.app : routes.signup
    },
    secondaryCta: { label: "See pricing", href: routes.pricing },
  }

  const logos = [ { label: "Logo 1" }, { label: "Logo 2" }, { label: "Logo 3" }, { label: "Logo 4" }, { label: "Logo 5" }, { label: "Logo 6" } ]

  const features = [
    { title: "Auth & Billing", description: "Rails 8 auth, Pay + Stripe out of the box.", icon: <CreditCard className="h-5 w-5" /> },
    { title: "SEO & Analytics", description: "OpenGraph tags, sitemap, and GA4 snippet.", icon: <Zap className="h-5 w-5" /> },
    { title: "DX", description: "Vite + shadcn/ui + Inertia React.", icon: <CheckCircle2 className="h-5 w-5" /> },
  ]

  const faq = [
    { question: "What's included?", answer: "Auth, billing, React UI, SEO, analytics, email, etc." },
    { question: "Can I self-host?", answer: "Yes, it's plain Rails + Postgres + Stripe." },
  ]

  const footerLinks = [
    { label: "Privacy", href: "/privacy" },
    { label: "Terms", href: "/terms" },
    { label: "Contact", href: "/contact" },
  ]

  return (
    <div>
      <Navbar />
      <Hero {...hero} />
      <SocialProof logos={logos} />
      <Features heading="Everything you need to ship" items={features} />
      <PricingCTA title="Simple pricing, no surprises." subtitle="Start free, upgrade when you're ready." cta={{ label: "View pricing", href: routes.pricing }} />
      <FAQ items={faq} />
      <Footer links={footerLinks} />
    </div>
  )
}
