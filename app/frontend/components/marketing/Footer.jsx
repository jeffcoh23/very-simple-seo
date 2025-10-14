import { Link } from "@inertiajs/react"
export default function Footer({ links = [], note }) {
  return (
    <footer className="mt-16 py-10 text-sm text-muted-foreground border-t-2">
      <div className="container flex flex-col md:flex-row items-center justify-between gap-4">
        <div>© {new Date().getFullYear()} VerySimpleSEO. All rights reserved.</div>
        {links.length > 0 && (
          <ul className="flex items-center gap-4">
            {links.map((l, i) => (
              <li key={i}><Link className="hover:text-primary hover:underline transition-colors" href={l.href}>{l.label}</Link></li>
            ))}
          </ul>
        )}
      </div>
      {note && <p className="mt-4 text-center">{note}</p>}
    </footer>
  )
}
