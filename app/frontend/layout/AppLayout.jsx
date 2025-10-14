import Flash from "@/components/Flash"
import EmailVerificationBanner from "@/components/EmailVerificationBanner"
import Navbar from "@/components/Navbar"

export default function AppLayout({ children }) {
  return (
    <div className="min-h-screen flex flex-col bg-background">
      <Navbar />
      <EmailVerificationBanner />
      <main className="flex-1">
        <div className="container py-10">
          <Flash />
          {children}
        </div>
      </main>
    </div>
  )
}
