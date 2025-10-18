import { useState } from "react"
import { useForm, usePage } from "@inertiajs/react"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Card, CardHeader, CardTitle, CardDescription, CardContent } from "@/components/ui/card"
import { Sparkles, Loader2, X, Plus, ChevronDown, ChevronUp } from "lucide-react"

export default function ProjectForm({
  project = null,
  mode = "create",
  onSubmit,
  onAutofill = null,
  submitButtonText = "Create Project",
  processing: externalProcessing = false,
  showButtons = true
}) {
  const { routes } = usePage().props
  const isEditMode = mode === "edit"

  // Collapsible section states
  const [expandedSections, setExpandedSections] = useState({
    basic: true,
    content: true,
    competitors: true
  })

  const toggleSection = (section) => {
    setExpandedSections(prev => ({ ...prev, [section]: !prev[section] }))
  }

  // Initialize form with useForm hook
  const { data, setData, processing, errors } = useForm({
    project: {
      name: project?.name || "",
      domain: project?.domain || "",
      niche: project?.niche || "",
      tone_of_voice: project?.tone_of_voice || "",
      sitemap_url: project?.sitemap_url || "",
      description: project?.description || "",
      seed_keywords: project?.seed_keywords || [],
      call_to_actions: project?.call_to_actions?.length > 0 ? project.call_to_actions : [],
      competitors: project?.competitors || []
    }
  })

  const [autofilling, setAutofilling] = useState(false)

  // Handle autofill button click
  const handleAutofill = async () => {
    if (!data.project.domain) {
      alert("Please enter a domain first")
      return
    }

    setAutofilling(true)

    try {
      const response = await fetch(routes.autofill_project, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
        },
        body: JSON.stringify({
          domain: data.project.domain,
          niche: data.project.niche
        })
      })

      const result = await response.json()

      if (result.error) {
        alert(`Autofill failed: ${result.error}`)
        return
      }

      // Update form with autofilled data
      setData("project", {
        ...data.project,
        description: result.description || data.project.description,
        seed_keywords: result.seed_keywords || data.project.seed_keywords,
        sitemap_url: result.sitemap_url || data.project.sitemap_url,
        competitors: result.competitors || data.project.competitors
      })

      // Show success message
      const seedCount = result.seed_keywords?.length || 0
      const compCount = result.competitors?.length || 0
      alert(`✨ Autofilled!\n${seedCount} seed keywords\n${compCount} competitors detected\n${result.sitemap_url ? '✓ Sitemap found' : ''}`)

      // Expand relevant sections
      setExpandedSections({ basic: true, content: true, competitors: true })

    } catch (error) {
      console.error("Autofill error:", error)
      alert("Autofill failed. Please try again.")
    } finally {
      setAutofilling(false)
    }
  }

  // CTA handlers
  const addCallToAction = () => {
    setData("project", {
      ...data.project,
      call_to_actions: [...data.project.call_to_actions, { text: "", url: "" }]
    })
  }

  const removeCallToAction = (index) => {
    const newCTAs = data.project.call_to_actions.filter((_, i) => i !== index)
    setData("project", {
      ...data.project,
      call_to_actions: newCTAs
    })
  }

  const updateCallToAction = (index, field, value) => {
    const newCTAs = [...data.project.call_to_actions]
    newCTAs[index][field] = value
    setData("project", {
      ...data.project,
      call_to_actions: newCTAs
    })
  }

  // Seed keyword handlers
  const addSeedKeyword = () => {
    setData("project", {
      ...data.project,
      seed_keywords: [...data.project.seed_keywords, ""]
    })
  }

  const removeSeedKeyword = (index) => {
    const newSeeds = data.project.seed_keywords.filter((_, i) => i !== index)
    setData("project", {
      ...data.project,
      seed_keywords: newSeeds
    })
  }

  const updateSeedKeyword = (index, value) => {
    const newSeeds = [...data.project.seed_keywords]
    newSeeds[index] = value
    setData("project", {
      ...data.project,
      seed_keywords: newSeeds
    })
  }

  // Competitor handlers
  const addCompetitor = () => {
    setData("project", {
      ...data.project,
      competitors: [...data.project.competitors, { domain: "", title: "" }]
    })
  }

  const removeCompetitor = (index) => {
    const newComps = data.project.competitors.filter((_, i) => i !== index)
    setData("project", {
      ...data.project,
      competitors: newComps
    })
  }

  const updateCompetitor = (index, field, value) => {
    const newComps = [...data.project.competitors]
    newComps[index][field] = value
    setData("project", {
      ...data.project,
      competitors: newComps
    })
  }

  const handleFormSubmit = (e) => {
    e.preventDefault()

    // Filter out empty CTAs before submission
    const cleanedData = {
      ...data,
      project: {
        ...data.project,
        call_to_actions: data.project.call_to_actions.filter(
          cta => cta.text?.trim() !== '' && cta.url?.trim() !== ''
        ),
        seed_keywords: data.project.seed_keywords.filter(
          keyword => keyword?.trim() !== ''
        ),
        competitors: data.project.competitors.filter(
          comp => comp.domain?.trim() !== ''
        )
      }
    }

    onSubmit(cleanedData, setData)
  }

  return (
    <form id="project-form" onSubmit={handleFormSubmit} className="space-y-6">
      {/* SECTION 1: Basic Information */}
      <Card>
        <CardHeader
          className="cursor-pointer hover:bg-muted/50 transition-colors"
          onClick={() => toggleSection('basic')}
        >
          <div className="flex items-center justify-between">
            <div>
              <CardTitle>Basic Information</CardTitle>
              <CardDescription>Project name, domain, and general settings</CardDescription>
            </div>
            {expandedSections.basic ? (
              <ChevronUp className="h-5 w-5 text-muted-foreground" />
            ) : (
              <ChevronDown className="h-5 w-5 text-muted-foreground" />
            )}
          </div>
        </CardHeader>

        {expandedSections.basic && (
          <CardContent className="space-y-6">
            {/* Project Name */}
            <div className="space-y-2">
              <Label htmlFor="name">
                Project Name <span className="text-destructive">*</span>
              </Label>
              <Input
                id="name"
                type="text"
                placeholder="My Awesome Website"
                value={data.project.name}
                onChange={(e) => setData("project", { ...data.project, name: e.target.value })}
                required
              />
              {errors["project.name"] && (
                <p className="text-sm text-destructive">{errors["project.name"]}</p>
              )}
            </div>

            {/* Domain with Autofill (only in create mode) */}
            <div className="space-y-2">
              <Label htmlFor="domain">
                Website Domain <span className="text-destructive">*</span>
              </Label>
              {!isEditMode && onAutofill ? (
                <div className="flex gap-2">
                  <Input
                    id="domain"
                    type="url"
                    placeholder="https://example.com"
                    value={data.project.domain}
                    onChange={(e) => setData("project", { ...data.project, domain: e.target.value })}
                    required
                    className="flex-1"
                  />
                  <Button
                    type="button"
                    variant="outline"
                    onClick={handleAutofill}
                    disabled={autofilling || !data.project.domain}
                  >
                    {autofilling ? (
                      <>
                        <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                        Analyzing...
                      </>
                    ) : (
                      <>
                        <Sparkles className="mr-2 h-4 w-4" />
                        Autofill
                      </>
                    )}
                  </Button>
                </div>
              ) : (
                <Input
                  id="domain"
                  type="url"
                  placeholder="https://example.com"
                  value={data.project.domain}
                  onChange={(e) => setData("project", { ...data.project, domain: e.target.value })}
                  required
                />
              )}
              {!isEditMode && (
                <p className="text-sm text-muted-foreground">
                  Click Autofill to automatically detect keywords, description, and competitors
                </p>
              )}
              {errors["project.domain"] && (
                <p className="text-sm text-destructive">{errors["project.domain"]}</p>
              )}
            </div>

            {/* Niche and Tone - Side by Side */}
            <div className="grid grid-cols-2 gap-4">
              {/* Niche */}
              <div className="space-y-2">
                <Label htmlFor="niche">Niche / Industry</Label>
                <select
                  id="niche"
                  value={data.project.niche}
                  onChange={(e) => setData("project", { ...data.project, niche: e.target.value })}
                  className="flex h-10 w-full rounded-md border border-input bg-background px-3 py-2 text-base ring-offset-background file:border-0 file:bg-transparent file:text-sm file:font-medium file:text-foreground placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50 md:text-sm"
                >
                  <option value="">Select a niche...</option>
                  <option value="SaaS">SaaS</option>
                  <option value="E-commerce">E-commerce</option>
                  <option value="Digital Marketing">Digital Marketing</option>
                  <option value="Health & Wellness">Health & Wellness</option>
                  <option value="Finance">Finance</option>
                  <option value="Education">Education</option>
                  <option value="Real Estate">Real Estate</option>
                  <option value="Technology">Technology</option>
                  <option value="Travel">Travel</option>
                  <option value="Food & Beverage">Food & Beverage</option>
                  <option value="Other">Other</option>
                </select>
                <p className="text-sm text-muted-foreground">
                  Helps us find relevant keywords
                </p>
              </div>

              {/* Tone of Voice */}
              <div className="space-y-2">
                <Label htmlFor="tone_of_voice">Tone of Voice</Label>
                <select
                  id="tone_of_voice"
                  value={data.project.tone_of_voice}
                  onChange={(e) => setData("project", { ...data.project, tone_of_voice: e.target.value })}
                  className="flex h-10 w-full rounded-md border border-input bg-background px-3 py-2 text-base ring-offset-background file:border-0 file:bg-transparent file:text-sm file:font-medium file:text-foreground placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50 md:text-sm"
                >
                  <option value="">Select a tone...</option>
                  <option value="Professional">Professional</option>
                  <option value="Casual">Casual</option>
                  <option value="Technical">Technical</option>
                  <option value="Conversational">Conversational</option>
                  <option value="Formal">Formal</option>
                  <option value="Friendly">Friendly</option>
                  <option value="Authoritative">Authoritative</option>
                </select>
                <p className="text-sm text-muted-foreground">
                  How should articles sound?
                </p>
              </div>
            </div>
          </CardContent>
        )}
      </Card>

      {/* SECTION 2: Content Strategy */}
      <Card>
        <CardHeader
          className="cursor-pointer hover:bg-muted/50 transition-colors"
          onClick={() => toggleSection('content')}
        >
          <div className="flex items-center justify-between">
            <div>
              <CardTitle>Content Strategy</CardTitle>
              <CardDescription>Description, keywords, and call-to-actions</CardDescription>
            </div>
            {expandedSections.content ? (
              <ChevronUp className="h-5 w-5 text-muted-foreground" />
            ) : (
              <ChevronDown className="h-5 w-5 text-muted-foreground" />
            )}
          </div>
        </CardHeader>

        {expandedSections.content && (
          <CardContent className="space-y-6">
            {/* Description */}
            <div className="space-y-2">
              <Label htmlFor="description">Description</Label>
              <textarea
                id="description"
                value={data.project.description}
                onChange={(e) => setData("project", { ...data.project, description: e.target.value })}
                placeholder="Brief description of what your website does (will be auto-filled)..."
                className="flex min-h-[80px] w-full rounded-md border border-input bg-background px-3 py-2 text-base ring-offset-background placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50 md:text-sm"
                rows={3}
              />
              <p className="text-sm text-muted-foreground">
                Used to generate more accurate keywords
              </p>
            </div>

            {/* Seed Keywords */}
            <div className="space-y-3">
              <div className="flex items-center justify-between">
                <div>
                  <Label>Seed Keywords</Label>
                  <p className="text-sm text-muted-foreground mt-1">
                    {isEditMode
                      ? "Initial keywords to expand for research. Changes require regenerating keyword research."
                      : "Initial keywords to expand for research (will be auto-generated if left empty)"
                    }
                  </p>
                </div>
                <Button type="button" variant="outline" size="sm" onClick={addSeedKeyword}>
                  <Plus className="mr-2 h-4 w-4" />
                  Add
                </Button>
              </div>

              {data.project.seed_keywords.length > 0 ? (
                <div className="space-y-2">
                  {data.project.seed_keywords.map((seed, index) => (
                    <div key={index} className="flex gap-2">
                      <Input
                        type="text"
                        placeholder="e.g., seo tools"
                        value={seed}
                        onChange={(e) => updateSeedKeyword(index, e.target.value)}
                        className="flex-1"
                      />
                      <Button
                        type="button"
                        variant="ghost"
                        size="icon"
                        onClick={() => removeSeedKeyword(index)}
                        className="shrink-0"
                      >
                        <X className="h-4 w-4" />
                      </Button>
                    </div>
                  ))}
                </div>
              ) : (
                <p className="text-sm text-muted-foreground italic">
                  No seed keywords yet. {!isEditMode ? "Use Autofill or " : ""}They'll be generated automatically.
                </p>
              )}
            </div>

            {/* Call to Actions */}
            <div className="space-y-3">
              <div className="flex items-center justify-between">
                <div>
                  <Label>Call to Actions (CTAs)</Label>
                  <p className="text-sm text-muted-foreground mt-1">
                    Add links to include in your articles (e.g., product pages, signup forms)
                  </p>
                </div>
                <Button type="button" variant="outline" size="sm" onClick={addCallToAction}>
                  <Plus className="mr-2 h-4 w-4" />
                  Add CTA
                </Button>
              </div>

              {data.project.call_to_actions.length > 0 ? (
                <div className="space-y-3">
                  {data.project.call_to_actions.map((cta, index) => (
                    <div key={index} className="flex gap-2 items-start p-3 border rounded-lg bg-muted/20">
                      <div className="flex-1 space-y-2">
                        <Input
                          type="text"
                          placeholder="CTA Text (e.g., Try it free)"
                          value={cta.text}
                          onChange={(e) => updateCallToAction(index, "text", e.target.value)}
                        />
                        <Input
                          type="url"
                          placeholder="URL (e.g., https://example.com/signup)"
                          value={cta.url}
                          onChange={(e) => updateCallToAction(index, "url", e.target.value)}
                        />
                      </div>
                      <Button
                        type="button"
                        variant="ghost"
                        size="icon"
                        onClick={() => removeCallToAction(index)}
                        className="shrink-0"
                      >
                        <X className="h-4 w-4" />
                      </Button>
                    </div>
                  ))}
                </div>
              ) : (
                <p className="text-sm text-muted-foreground italic">
                  No CTAs yet. Click "Add CTA" to add links for your articles.
                </p>
              )}
            </div>
          </CardContent>
        )}
      </Card>

      {/* SECTION 3: Competitors & Discovery */}
      <Card>
        <CardHeader
          className="cursor-pointer hover:bg-muted/50 transition-colors"
          onClick={() => toggleSection('competitors')}
        >
          <div className="flex items-center justify-between">
            <div>
              <CardTitle>Competitors & Discovery</CardTitle>
              <CardDescription>Track competitors and sitemap for analysis</CardDescription>
            </div>
            {expandedSections.competitors ? (
              <ChevronUp className="h-5 w-5 text-muted-foreground" />
            ) : (
              <ChevronDown className="h-5 w-5 text-muted-foreground" />
            )}
          </div>
        </CardHeader>

        {expandedSections.competitors && (
          <CardContent className="space-y-6">
            {/* Competitors */}
            <div className="space-y-3">
              <div className="flex items-center justify-between">
                <div>
                  <Label>Competitors</Label>
                  <p className="text-sm text-muted-foreground mt-1">
                    Competitor domains to analyze for keywords and content gaps
                  </p>
                </div>
                <Button type="button" variant="outline" size="sm" onClick={addCompetitor}>
                  <Plus className="mr-2 h-4 w-4" />
                  Add
                </Button>
              </div>

              {data.project.competitors.length > 0 ? (
                <div className="space-y-2">
                  {data.project.competitors.map((competitor, index) => (
                    <div key={index} className="flex gap-2 items-start p-3 border rounded-lg bg-muted/20">
                      <div className="flex-1 space-y-2">
                        <Input
                          type="url"
                          placeholder="Competitor domain (e.g., https://competitor.com)"
                          value={competitor.domain}
                          onChange={(e) => updateCompetitor(index, "domain", e.target.value)}
                        />
                        <Input
                          type="text"
                          placeholder="Site title (optional)"
                          value={competitor.title || ""}
                          onChange={(e) => updateCompetitor(index, "title", e.target.value)}
                        />
                        {competitor.source && (
                          <p className="text-xs text-muted-foreground">
                            Source: <span className="capitalize">{competitor.source}</span>
                          </p>
                        )}
                      </div>
                      <Button
                        type="button"
                        variant="ghost"
                        size="icon"
                        onClick={() => removeCompetitor(index)}
                        className="shrink-0"
                      >
                        <X className="h-4 w-4" />
                      </Button>
                    </div>
                  ))}
                </div>
              ) : (
                <p className="text-sm text-muted-foreground italic">
                  No competitors yet. {!isEditMode ? "Use Autofill to detect them automatically, or " : ""}Add them manually.
                </p>
              )}
            </div>

            {/* Sitemap URL */}
            <div className="space-y-2">
              <Label htmlFor="sitemap_url">Sitemap URL</Label>
              <Input
                id="sitemap_url"
                type="url"
                placeholder="https://example.com/sitemap.xml (auto-detected)"
                value={data.project.sitemap_url}
                onChange={(e) => setData("project", { ...data.project, sitemap_url: e.target.value })}
              />
              <p className="text-sm text-muted-foreground">
                Optional: We'll analyze your existing content structure
              </p>
            </div>
          </CardContent>
        )}
      </Card>

      {/* Submit Button */}
      {showButtons && (
        <div className="flex justify-end">
          <Button
            type="submit"
            disabled={processing || externalProcessing}
            className="border-2 shadow-md hover:shadow-lg"
          >
            {(processing || externalProcessing) ? "Saving..." : submitButtonText}
          </Button>
        </div>
      )}
    </form>
  )
}
