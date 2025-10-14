import Flash from "@/components/Flash"
import Navbar from "@/components/marketing/SiteHeader"

export default function AuthLayout({ children }) {
  return (
    <div className="bg-glow">
      <Navbar />
      <div className="section-py">
        <div className="container">
          <Flash />
          {children}
        </div>
      </div>
    </div>
  )
}
