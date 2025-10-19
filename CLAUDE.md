
> Playbook for using Claude/Cursor with this Rails + Inertia + Vite + Tailwind v4 template.

---

## 0) Non-negotiables

- **AUTOMATED WORKFLOW**: Follow `.claude/workflows/automated-development.md` - Claude handles branch creation, implementation, testing, and commits. NEVER commit to `main` or push to remote.
- **Feature requests follow pattern**: Create feature branch → Implement → Test → Commit → Summary for review
- Prefer **small tasks** (30–90 minutes). If scope creeps, suggest a split.
- **Add/modify tests** for any behavior change.
- If blocked, **ask one focused question** and propose a default path.
- Follow the stack & conventions below. Don't add infra/deps without approval.

---

## 1) Stack & layout (assumed)

- **Server:** Rails 8 + Postgres; Solid Queue for jobs; Rails auth generator.
- **SPA:** Inertia (React) via Vite.
- **Dev Server:** Uses Procfile.dev - Rails runs on **localhost:5000** (not 3000)
- **Styling:** Tailwind **v4** tokens defined in `@theme` (see `app/frontend/entrypoints/application.css`).
- **UI:** shadcn/ui components in `app/frontend/components/ui/*`.
- **Payments:** Stripe via `pay` (signature-verified webhooks).
- **Email:** Resend (prod) / letter_opener_web (dev).
- **Deployment:** Fly.io with custom domain signallab.app

**App structure**

- Pages → `app/frontend/pages/**`
- Components → `app/frontend/components/**` (incl. `marketing/**`, `ui/**`)
- Authenticated shell → `app/frontend/layout/AppLayout.jsx`

**Navigation & Routing**

- Internal routes: **`<Link href="/path" />`** (Inertia).
- Use `<a>` only for external links or non-Inertia targets.
- **NEVER hardcode routes in frontend code.** Always use Inertia shared routes.
- Share routes from Rails controller using `Inertia.share` and access via `usePage().props.routes`.
- API endpoints should also use shared routes, not hardcoded URLs.
- **ALL routes MUST be defined in ApplicationController#inertia_share** - no exceptions.
- For dynamic routes, use lambda functions: `project: ->(id) { project_path(id) }` → `routes.project(123)`
- This includes: page navigation, form actions, API calls, delete actions, export links

**Design System**

- **Follow `docs/DESIGN_SYSTEM.md`** for colors, typography, layouts, and component patterns.
- Use **warm color palette** (forest green primary, amber accent) - not default blue/purple.
- **Flexbox-first layouts** - avoid complex CSS Grid patterns.
- **Typography**: Space Grotesk for headings (`font-display`), Inter for body, JetBrains Mono for code.
- **Border emphasis**: Use `border-2` for important elements (cards, buttons).
- **Extend shadcn components** with custom classes, don't rebuild them.
- **Semantic colors**: Use `success`, `warning`, `destructive`, `info` for SEO context.
- **Custom utilities**: `.bg-warm`, `.bg-glow`, `.hover-lift`, `.shadow-emphasis`, `.border-emphasis`.

**Layout rhythm**

- Wrap screens in **`.container`** for width + side padding (`.container-wide`, `.container-narrow` for variants).
- Use **`.section-py`** for vertical spacing (`.section-py-lg`, `.section-py-sm` for variants).
- Tailwind v4 utilities from tokens: `bg-background`, `text-foreground`, `text-primary`, `text-accent`, etc.
- Use warm backgrounds: `bg-background` (warm cream), not pure white.

---

## 2) How to ask for work (task template)

```md
### Task

<one-sentence goal>

### Context

- Files/dirs: <paths>
- Inputs/outputs & edge cases:
- Constraints / style notes:

### Steps to follow

1. Add or adjust tests (failing first)
2. Implement code
3. Run: `bin/rails test`
4. Summarize changes & propose follow-ups

### Acceptance checks

- Tests fail before impl, pass after
- Internal links use Inertia `<Link/>`
- Controls use shadcn/ui (Button, Input, Label, Card…)
- Tailwind v4 tokens/utilities; `.container` + `.section-py` where appropriate
- No new deps unless approved
````

---

## 3) Working style

* Default to **boring, explicit** Rails: services for business logic, skinny controllers.
* Keep changes **atomic** (one concern per request).
* Document any **tradeoffs** in 2–5 lines when returning work.
* **Update SYSTEM_ARCHITECTURE.md** when adding new features, changing flows, or modifying integrations.

---

## 4) Conventions & invariants

### Rails

* Controllers thin; business logic in `app/services/**`; query objects if needed.
* Strong params only; never `.permit!`.
* Jobs **idempotent**; avoid sleeps; backoff responsibly.
* Public actions must be explicit: `allow_unauthenticated_access`.
* Stripe webhooks: verify signature; don’t log secrets/PII.

### Inertia + React

* Pages under `app/frontend/pages/**`; reusable parts under `components/**`.
* **ALWAYS create components for repeated UI patterns** - banners, forms, cards, etc.
* Break large page components into smaller, focused components in `components/app/`.
* Internal navigation uses Inertia `<Link/>`.
* Prefer shadcn/ui primitives for inputs/buttons/cards, not ad-hoc Tailwind divs.
* **Use Lucide React for icons** - import from `lucide-react` (e.g., `import { Check, X, Plus } from "lucide-react"`). Never use inline SVG.
* Use `.mcp.json` and shadcn MCP server when adding new UI components.
* Co-locate small components; lift state only when necessary.

**Component Guidelines:**
* Create components when you see repeated JSX patterns (banners, modals, forms)
* Break up page components >100 lines into focused sub-components  
* Structure: `components/ui/` (shadcn), `components/app/` (app-specific), `components/marketing/` (public)
* **Use real data, not hardcoded values** - always check if data should come from props/API
* **Create modular, reusable components** instead of monolithic page files

**Code Quality & Modularity:**
* **No hardcoded data** - always use real data from backend/props
* **Component composition** - build pages from smaller, focused components
* **Single responsibility** - each component should have one clear purpose
* **Reusable design** - components should work in multiple contexts
* **Proper data flow** - pass data down through props, not embedded constants
* **Clean imports** - organize imports: React hooks, UI components, utilities, types

### Tailwind v4

* Theme tokens live in `@theme` (see `application.css`).
* Use utilities derived from tokens (e.g., `bg-background`) instead of hex.
* Keep screens balanced with `.container` and vertical rhythm via `.section-py`.
* Don’t modify `tailwind.config.js` unless required by UI tooling.

### Accessibility & UX

* Visible focus states (shadcn covers most); verify keyboard paths.
* Every input has a `<Label>`.
* Communicate async states (e.g., `processing` disables Button).

---

## 5) Testing guidance

* Runner: **Minitest** (`bin/rails test`).

* Where:

  * Services → `test/services/**`
  * Controllers → `test/controllers/**`
  * Models → `test/models/**`

* Include:

  * A meaningful assertion (beyond “200 OK”)
  * Happy path **and** an edge case
  * Deterministic setup (stub time, seed RNG, stub external services)

*(If JS tests become necessary, propose a minimal `vitest` setup with 1–2 examples, but ask first.)*

---

## 6) Review checklist (pre-submit)

* [ ] Tests added/updated; `bin/rails test` passes locally
* [ ] Inertia `<Link/>` for internal navigation
* [ ] shadcn/ui used for controls & cards
* [ ] Tailwind v4 tokens/utilities; `.container` and `.section-py` applied
* [ ] Public endpoints explicitly `allow_unauthenticated_access`
* [ ] No secrets/PII in logs; minimal external API chatter
* [ ] SYSTEM_ARCHITECTURE.md updated if new features/integrations were added

---

## 7) Useful snippets

**Controller → Inertia**

```rb
class SettingsController < ApplicationController
  def show
    render inertia: "App/Settings"
  end
end
```

**Internal link (Inertia with shared routes)**

```jsx
import { Link, usePage } from "@inertiajs/react";

function MyComponent() {
  const { routes } = usePage().props;
  return <Link href={routes.dashboard}>Dashboard</Link>;
}
```

**Sharing routes from Rails controller**

```rb
# app/controllers/application_controller.rb
before_action :set_inertia_defaults

def set_inertia_defaults
  Inertia.share do
    {
      routes: {
        dashboard: Rails.application.routes.url_helpers.dashboard_path,
        projects: Rails.application.routes.url_helpers.projects_path,
        # Add all frontend-needed routes here
      }
    }
  end
end
```

**API calls with shared routes**

```jsx
import { usePage } from "@inertiajs/react";
import { api } from "@/lib/api";

function useApiWithRoutes() {
  const { routes } = usePage().props;
  
  return {
    createProject: (data) => api.post(routes.projects, data),
    // Use shared routes instead of hardcoded URLs
  };
}
```

**shadcn Card**

```jsx
import { Card, CardHeader, CardTitle, CardContent } from "@/components/ui/card";

<Card className="rounded-2xl">
  <CardHeader>
    <CardTitle>Title</CardTitle>
  </CardHeader>
  <CardContent>Content</CardContent>
</Card>;
```

**Page spacing & container**

```jsx
export default function Example() {
  return (
    <section className="section-py">
      <div className="container">{/* content */}</div>
    </section>
  );
}
```

---

## 8) Code Quality Standards

### Modularity & Component Design

* **Break down large components** - Any component >100 lines should be split
* **Create focused sub-components** - Each component has one clear responsibility
* **Use component composition** - Build pages from smaller, reusable parts
* **Proper data handling** - No hardcoded arrays/objects, use real data from backend
* **Consistent file organization** - Group related components in logical directories

### Data & State Management

* **Real data only** - Never use hardcoded arrays for dynamic content
* **Check data sources** - Verify if data should come from backend/props
* **Proper prop types** - Components should expect and validate proper data shapes
* **Clean data flow** - Data flows down through props, events bubble up
* **Handle edge cases** - Account for loading states, empty data, errors

### Development Hygiene

* **Remove unused code** - Regularly audit and delete unused files/functions
* **Clean up imports** - Remove unused imports, organize remaining ones
* **Consistent naming** - Use clear, descriptive names for components/functions
* **Error handling** - Handle API failures, missing data gracefully
* **Performance considerations** - Use React best practices (keys, memo when needed)

### Review Checklist for Components

* [ ] Uses real data from props/backend, no hardcoded arrays
* [ ] Single, focused responsibility
* [ ] Reusable in different contexts
* [ ] Proper error/loading state handling
* [ ] Clean, organized imports
* [ ] Follows shadcn/ui + Tailwind v4 patterns
* [ ] Accessible (proper labels, focus states)

---

## 9) VerySimpleSEO Development Notes

**CRITICAL: This is a GENERIC SaaS SEO tool, NOT just for SignalLab**
- Service code MUST work for ANY SaaS project (not hardcoded for one brand)
- Always use `project.name`, `project.domain`, `project.call_to_actions` (dynamic)
- NEVER hardcode "SignalLab" or specific brand names in service code
- Article generation rules belong in service PROMPTS, not here

## 10) Roadmaps

This file is **general** for the template.
For each new app built on it, add a project-specific `docs/ROADMAP.md` with small, testable steps using the task template above.
Claude/Cursor should follow that roadmap while respecting everything in this playbook.
- VerySimpleSEO Design System established in @docs/DESIGN_SYSTEM.md