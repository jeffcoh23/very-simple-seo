# VerySimpleSEO Design System

> A warm, confident design language for data-driven SEO tools — not another gray SaaS.

---

## Philosophy

**"Data-driven confidence with warmth"**

We're building an SEO tool that feels approachable and trustworthy, not cold and corporate. Our design system breaks away from typical shadcn/ui defaults while staying easy to implement.

### What Makes Us Different:
- **Warm palette** - forest green + amber, not blue/purple
- **Geometric typography** - Space Grotesk headlines for personality
- **Flexbox-first** - practical layouts, not complex grids
- **Border emphasis** - 2px borders make data feel solid
- **Subtle gradients** - warmth without distraction

### Design Principles:
1. **Clarity First** - SEO data should be scannable and clear
2. **Warm, Not Cold** - Trustworthy but approachable
3. **Confident, Not Loud** - Strong without being aggressive
4. **Easy to Code** - Extend shadcn, don't rebuild it

---

## Color System: "Organic Growth"

### Primary Palette

```css
/* Primary - Deep Forest Green (growth, trust, organic) */
--color-primary: hsl(152 45% 35%);
--color-primary-foreground: hsl(0 0% 100%);
--color-primary-soft: hsl(152 45% 95%);     /* Subtle backgrounds */

/* Accent - Warm Amber (energy, action, opportunity) */
--color-accent: hsl(35 91% 58%);
--color-accent-foreground: hsl(0 0% 100%);
--color-accent-soft: hsl(35 91% 96%);

/* Background - Warm Cream (not harsh white) */
--color-background: hsl(35 20% 98%);
--color-foreground: hsl(152 25% 15%);       /* Deep charcoal text */

/* Card/Surfaces */
--color-card: hsl(0 0% 100%);
--color-card-foreground: hsl(152 25% 15%);
```

### Semantic Colors (SEO Context)

```css
/* Success - Opportunity/Easy Keywords */
--color-success: hsl(142 76% 36%);          /* Green-600 */
--color-success-soft: hsl(142 76% 95%);

/* Warning - Medium Difficulty */
--color-warning: hsl(38 92% 50%);           /* Amber-500 */
--color-warning-soft: hsl(38 92% 95%);

/* Destructive - Hard/High Competition */
--color-destructive: hsl(0 84% 60%);
--color-destructive-soft: hsl(0 84% 95%);

/* Info - Informational Intent */
--color-info: hsl(199 89% 48%);             /* Sky-500 */
--color-info-soft: hsl(199 89% 96%);

/* Muted - Secondary Data */
--color-muted: hsl(35 15% 92%);             /* Warm gray */
--color-muted-foreground: hsl(35 10% 45%);
```

### Border & Focus

```css
--color-border: hsl(35 15% 88%);            /* Warm border */
--color-input: hsl(35 15% 88%);
--ring: hsl(152 45% 35%);                   /* Primary focus ring */
```

### When to Use Each Color:

| Color | Use Case | Example |
|-------|----------|---------|
| **Primary** | Main CTAs, navigation active states, primary actions | "Create Project", "Generate Article" buttons |
| **Accent** | Secondary actions, highlights, hover states | "Autofill" button, opportunity scores |
| **Success** | Easy keywords, completed states, positive metrics | Difficulty badges (Easy), success messages |
| **Warning** | Medium difficulty, caution states | Difficulty badges (Medium), pending research |
| **Destructive** | Hard keywords, delete actions, errors | Difficulty badges (Hard), delete project |
| **Info** | Informational intent, neutral data | Intent badges, tooltips, help text |
| **Muted** | Secondary text, disabled states, subtle backgrounds | Placeholder text, disabled buttons |

---

## Typography: "Geometric Confidence"

### Font Stack

```css
/* Display/Headings - Space Grotesk (geometric, distinctive) */
--font-display: 'Space Grotesk', ui-sans-serif, system-ui, sans-serif;

/* Body/Interface - Inter (clean, readable) */
--font-body: 'Inter', ui-sans-serif, system-ui, sans-serif;

/* Monospace - JetBrains Mono (code, data) */
--font-mono: 'JetBrains Mono', 'Fira Code', ui-monospace, monospace;
```

### Type Scale

```css
/* Headings - Use Space Grotesk */
.text-h1 { font-size: 3rem; line-height: 1.2; font-weight: 700; }      /* 48px */
.text-h2 { font-size: 2.25rem; line-height: 1.3; font-weight: 700; }   /* 36px */
.text-h3 { font-size: 1.875rem; line-height: 1.3; font-weight: 600; }  /* 30px */
.text-h4 { font-size: 1.5rem; line-height: 1.4; font-weight: 600; }    /* 24px */
.text-h5 { font-size: 1.25rem; line-height: 1.4; font-weight: 600; }   /* 20px */
.text-h6 { font-size: 1rem; line-height: 1.5; font-weight: 600; }      /* 16px */

/* Body - Use Inter */
.text-base { font-size: 1rem; line-height: 1.5; }           /* 16px */
.text-lg { font-size: 1.125rem; line-height: 1.5; }         /* 18px */
.text-sm { font-size: 0.875rem; line-height: 1.5; }         /* 14px */
.text-xs { font-size: 0.75rem; line-height: 1.5; }          /* 12px */

/* Monospace - Use JetBrains Mono */
.font-mono { font-family: var(--font-mono); }
```

### Usage Rules:

**Space Grotesk (Display Font):**
- ✅ Page titles (h1, h2)
- ✅ Section headings (h3)
- ✅ Card titles
- ✅ Large UI labels
- ❌ Body text (too geometric for long reading)
- ❌ Form labels (use Inter for consistency)

**Inter (Body Font):**
- ✅ All body text
- ✅ Form inputs and labels
- ✅ Table content
- ✅ Buttons
- ✅ Small headings (h4+)

**JetBrains Mono:**
- ✅ Keywords displayed
- ✅ Domain names
- ✅ Code snippets
- ✅ Technical data (URLs, tokens)

### Font Loading Strategy:

```html
<!-- In layout head -->
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@400;500;600;700&family=Inter:wght@400;500;600;700&family=JetBrains+Mono:wght@400;500;600&display=swap" rel="stylesheet">
```

---

## Layout System: Flexbox-First

### Container Patterns

```css
/* Default container */
.container {
  max-width: 1200px;
  margin: 0 auto;
  padding: 0 1.5rem;  /* 24px */
}

/* Wide container (dashboards, tables) */
.container-wide {
  max-width: 1400px;
  margin: 0 auto;
  padding: 0 2rem;    /* 32px */
}

/* Narrow container (forms, articles) */
.container-narrow {
  max-width: 800px;
  margin: 0 auto;
  padding: 0 1.5rem;
}
```

### Section Spacing

```css
/* Vertical section spacing */
.section-py { padding-top: 4rem; padding-bottom: 4rem; }      /* 64px */
.section-py-lg { padding-top: 6rem; padding-bottom: 6rem; }   /* 96px */
.section-py-sm { padding-top: 2rem; padding-bottom: 2rem; }   /* 32px */
```

### Common Flex Patterns

#### 1. Sidebar + Content Layout
```jsx
<div className="container">
  <div className="flex flex-row gap-6">
    {/* Sidebar - fixed width */}
    <aside className="w-64 flex-shrink-0">
      <SideNav />
    </aside>

    {/* Main content - fills remaining space */}
    <main className="flex-1 min-w-0">
      <Content />
    </main>
  </div>
</div>
```

#### 2. Card Grid (Flexbox, not CSS Grid)
```jsx
<div className="flex flex-wrap gap-6">
  {items.map(item => (
    <Card className="flex-1 min-w-[300px] max-w-[400px]">
      {item}
    </Card>
  ))}
</div>
```

#### 3. Header with Actions
```jsx
<div className="flex flex-row items-center justify-between gap-4">
  <div className="flex-1">
    <h1>Page Title</h1>
    <p className="text-muted-foreground">Description</p>
  </div>
  <div className="flex gap-2">
    <Button variant="outline">Cancel</Button>
    <Button>Save</Button>
  </div>
</div>
```

#### 4. Stacked Form Sections
```jsx
<div className="flex flex-col gap-6">
  <Card>Section 1</Card>
  <Card>Section 2</Card>
  <Card>Section 3</Card>
</div>
```

#### 5. Horizontal Button Group
```jsx
<div className="flex flex-row gap-2 items-center">
  <Button>Primary Action</Button>
  <Button variant="outline">Secondary</Button>
  <Button variant="ghost">Tertiary</Button>
</div>
```

---

## Border & Radius System

### Border Emphasis

Use **2px borders** for important UI elements to make data feel solid and trustworthy.

```jsx
// ✅ DO: Emphasize data cards
<Card className="border-2 border-border">
  <KeywordData />
</Card>

// ✅ DO: Strong CTAs
<Button className="border-2 border-primary">
  Generate Keywords
</Button>

// ❌ DON'T: Default 1px everywhere
<Card className="border">  {/* Too subtle */}
```

### Radius System

Mix sharp and soft radii for visual interest without overwhelming.

```css
/* Radius tokens */
--radius-sharp: 0.25rem;      /* 4px - Data tables, badges */
--radius-soft: 1rem;           /* 16px - Buttons, cards */
--radius-dramatic: 2rem;       /* 32px - Hero elements */

/* Asymmetric utility (optional) */
.card-offset-radius {
  border-top-left-radius: var(--radius-sharp);
  border-top-right-radius: var(--radius-dramatic);
  border-bottom-left-radius: var(--radius-dramatic);
  border-bottom-right-radius: var(--radius-sharp);
}
```

### Radius Usage Guide:

| Element | Radius | Reasoning |
|---------|--------|-----------|
| **Data Tables** | Sharp (4px) | Precise, data-focused |
| **Badges** | Sharp (4px) | Compact, label-like |
| **Buttons** | Soft (16px) | Friendly, clickable |
| **Cards** | Soft (16px) | Container feel |
| **Modals** | Soft (16px) | Modern, polished |
| **Hero Sections** | Dramatic (32px) | Statement pieces |

---

## Custom Utilities

### Subtle Gradients

```css
/* Warm glow background (hero sections) */
.bg-glow {
  background: radial-gradient(
    1200px 400px at 50% -10%,
    hsl(35 80% 94%),    /* Warm peachy glow */
    transparent 70%
  );
}

/* Warm gradient overlay (cards) */
.bg-warm {
  background: linear-gradient(
    135deg,
    hsl(35 20% 98%) 0%,
    hsl(152 15% 97%) 100%
  );
}

/* Accent gradient (CTA buttons) */
.bg-accent-gradient {
  background: linear-gradient(
    135deg,
    hsl(152 45% 35%) 0%,
    hsl(152 45% 40%) 100%
  );
}
```

### Shadow Emphasis

```css
/* Stronger shadows for elevated cards */
.shadow-emphasis {
  box-shadow:
    0 1px 3px 0 rgb(0 0 0 / 0.1),
    0 4px 6px -4px rgb(0 0 0 / 0.1),
    0 0 0 2px hsl(35 15% 88%);   /* Subtle border glow */
}

/* Hover lift effect */
.hover-lift {
  transition: transform 0.2s ease, box-shadow 0.2s ease;
}
.hover-lift:hover {
  transform: translateY(-2px);
  box-shadow: 0 12px 24px -4px rgb(0 0 0 / 0.12);
}
```

---

## Component Customizations

### Extending shadcn Components

**Philosophy:** Don't rebuild shadcn components — extend them with custom classes.

#### Button Variants

```jsx
// Primary (default with border emphasis)
<Button className="border-2 shadow-md hover:shadow-lg">
  Generate Keywords
</Button>

// Accent action
<Button className="bg-accent hover:bg-accent/90 border-2 border-accent">
  Autofill
</Button>

// Gradient CTA (hero)
<Button className="bg-accent-gradient text-white border-0 shadow-lg hover:shadow-xl">
  Get Started
</Button>

// Outline with emphasis
<Button variant="outline" className="border-2 hover:bg-primary/5">
  Cancel
</Button>
```

#### Card Variants

```jsx
// Standard card with border emphasis
<Card className="border-2 hover-lift">
  <CardContent>...</CardContent>
</Card>

// Warm background card
<Card className="bg-warm border-2">
  <CardContent>...</CardContent>
</Card>

// Elevated card (important data)
<Card className="border-2 shadow-emphasis">
  <CardContent>...</CardContent>
</Card>

// Asymmetric card (hero/spotlight)
<Card className="card-offset-radius border-2 bg-glow">
  <CardContent>...</CardContent>
</Card>
```

#### Badge Variants

```jsx
// Intent badges (SEO-specific)
<Badge className="bg-info-soft text-info border border-info/20">
  Informational
</Badge>

<Badge className="bg-success-soft text-success border border-success/20 font-semibold">
  Commercial
</Badge>

// Difficulty badges
<Badge className="bg-success-soft text-success border-2 border-success/30">
  Easy (25)
</Badge>

<Badge className="bg-warning-soft text-warning border-2 border-warning/30">
  Medium (55)
</Badge>

<Badge className="bg-destructive-soft text-destructive border-2 border-destructive/30">
  Hard (85)
</Badge>

// Source badges
<Badge variant="outline" className="border-2 text-xs">
  auto-detected
</Badge>
```

#### Input & Form Elements

```jsx
// Standard input with border emphasis
<Input className="border-2 focus:ring-2 focus:ring-primary/20" />

// Textarea with warm background
<textarea className="bg-warm border-2 border-border rounded-lg p-3" />

// Select dropdown
<select className="border-2 border-border rounded-lg px-3 py-2 bg-white">
  <option>Select option</option>
</select>
```

---

## Icon System

**Library:** Lucide React (only)

### Icon Usage Rules:

```jsx
import { Sparkles, TrendingUp, Search, X } from "lucide-react"

// ✅ DO: Use Lucide React
<Button>
  <Sparkles className="mr-2 h-4 w-4" />
  Autofill
</Button>

// ✅ DO: Consistent sizing
<TrendingUp className="h-5 w-5 text-success" />  // Standard size
<Search className="h-6 w-6 text-primary" />      // Larger for emphasis

// ❌ DON'T: Inline SVG
<svg>...</svg>  // Never do this

// ❌ DON'T: Mix icon libraries
import { SomeIcon } from "react-icons"  // Don't use other libraries
```

### Icon Color Guidelines:

- **Primary actions:** `text-primary`
- **Success/opportunity:** `text-success`
- **Warning/medium:** `text-warning`
- **Error/hard:** `text-destructive`
- **Neutral/info:** `text-muted-foreground`
- **Accent highlights:** `text-accent`

---

## Responsive Patterns

### Breakpoints (Tailwind defaults)

```css
sm: 640px   /* Mobile landscape */
md: 768px   /* Tablet */
lg: 1024px  /* Desktop */
xl: 1280px  /* Large desktop */
```

### Responsive Flex Patterns

```jsx
// Stack on mobile, side-by-side on desktop
<div className="flex flex-col md:flex-row gap-6">
  <aside className="md:w-64">Sidebar</aside>
  <main className="flex-1">Content</main>
</div>

// Full-width cards on mobile, flex grid on desktop
<div className="flex flex-col sm:flex-row sm:flex-wrap gap-4">
  {items.map(item => (
    <Card className="sm:flex-1 sm:min-w-[280px]">
      {item}
    </Card>
  ))}
</div>

// Horizontal buttons on desktop, stacked on mobile
<div className="flex flex-col sm:flex-row gap-2">
  <Button>Primary</Button>
  <Button variant="outline">Secondary</Button>
</div>
```

---

## Quick Reference Cheatsheet

### Colors Copy-Paste

```jsx
// Backgrounds
className="bg-background"        // Main app background (warm cream)
className="bg-card"              // Card surfaces (white)
className="bg-warm"              // Warm gradient overlay
className="bg-glow"              // Warm radial glow

// Text
className="text-foreground"      // Primary text (deep charcoal)
className="text-muted-foreground" // Secondary text
className="text-primary"         // Brand text (forest green)
className="text-accent"          // Highlight text (amber)

// Borders
className="border-2 border-border"           // Standard border
className="border-2 border-primary"          // Primary emphasis
className="border-2 border-success/20"       // Success tint
```

### Common Component Patterns

```jsx
// Primary CTA Button
<Button className="border-2 shadow-md hover:shadow-lg">
  Action
</Button>

// Data Card
<Card className="border-2 hover-lift">
  <CardHeader>
    <CardTitle className="font-display">Title</CardTitle>
  </CardHeader>
  <CardContent>Content</CardContent>
</Card>

// Difficulty Badge
<Badge className="bg-success-soft text-success border-2 border-success/30 font-semibold">
  Easy (25)
</Badge>

// Form Section
<div className="space-y-4">
  <Label htmlFor="field">Label</Label>
  <Input id="field" className="border-2" />
  <p className="text-sm text-muted-foreground">Helper text</p>
</div>
```

---

## Do's and Don'ts

### ✅ DO:

- Use warm color palette (primary, accent, warm backgrounds)
- Add `border-2` for emphasis on important elements
- Use Space Grotesk for headings, Inter for body
- Extend shadcn components with custom classes
- Use flexbox for layouts
- Import icons from `lucide-react`
- Use semantic color tokens (`bg-primary`, `text-accent`)
- Add subtle gradients with `.bg-warm` or `.bg-glow`

### ❌ DON'T:

- Use default purple/blue primary colors
- Use pure white backgrounds everywhere (`hsl(0 0% 100%)`)
- Use 1px borders on everything (too subtle)
- Rebuild shadcn components from scratch
- Use CSS Grid for complex layouts (stick to flexbox)
- Use inline SVG or other icon libraries
- Hardcode HSL values in components (use tokens)
- Add heavy gradients everywhere (subtle only)

---

## Implementation Checklist

When starting a new feature or page:

- [ ] Use `font-display` class for main headings
- [ ] Apply warm color palette (not default blue/purple)
- [ ] Add `border-2` to important cards and buttons
- [ ] Use flexbox patterns from this doc
- [ ] Import icons from `lucide-react`
- [ ] Test with real data (no hardcoded arrays)
- [ ] Verify text contrast (WCAG AA minimum)
- [ ] Check responsive breakpoints (mobile-first)

---

## Resources

### Font Links:
- [Space Grotesk on Google Fonts](https://fonts.google.com/specimen/Space+Grotesk)
- [Inter on Google Fonts](https://fonts.google.com/specimen/Inter)
- [JetBrains Mono on Google Fonts](https://fonts.google.com/specimen/JetBrains+Mono)

### Icon Library:
- [Lucide React Icons](https://lucide.dev/icons/)

### Color Contrast Checker:
- [WebAIM Contrast Checker](https://webaim.org/resources/contrastchecker/)

### Tailwind v4 Docs:
- [Tailwind CSS v4 Documentation](https://tailwindcss.com/docs)

---

**Last Updated:** January 2025
**Maintained By:** VerySimpleSEO Team
