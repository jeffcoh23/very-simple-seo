import { useState } from "react"
import { Link, usePage, router } from "@inertiajs/react"
import AppLayout from "@/layout/AppLayout"
import { Button } from "@/components/ui/button"
import { Card, CardHeader, CardTitle, CardDescription, CardContent, CardFooter } from "@/components/ui/card"
import { Label } from "@/components/ui/label"
import { Badge } from "@/components/ui/badge"
import {
  ArrowLeft, FileText, TrendingUp, Target,
  DollarSign, Coins, AlertCircle, Info
} from "lucide-react"

export default function ArticlesNew() {
  const { keyword, project, user_credits, estimated_cost } = usePage().props
  const { routes } = usePage().props

  const [targetWordCount, setTargetWordCount] = useState(2000)
  const [isSubmitting, setIsSubmitting] = useState(false)

  const handleGenerate = () => {
    if (user_credits < 1) {
      alert("You're out of credits. Please upgrade your plan.")
      return
    }

    setIsSubmitting(true)

    router.post(
      project.routes.create_article,
      {
        keyword_id: keyword.id,
        target_word_count: targetWordCount
      },
      {
        onFinish: () => setIsSubmitting(false)
      }
    )
  }

  const getIntentBadge = (intent) => {
    const colors = {
      informational: "bg-info-soft text-info border-2 border-info/30",
      commercial: "bg-success-soft text-success border-2 border-success/30",
      transactional: "bg-accent-soft text-accent border-2 border-accent/30",
      navigational: "bg-muted text-muted-foreground border-2"
    }
    return colors[intent] || colors.navigational
  }

  const getDifficultyBadge = (difficulty) => {
    if (difficulty <= 30) return {
      label: "Easy",
      color: "bg-success-soft text-success border-2 border-success/30 font-semibold"
    }
    if (difficulty <= 60) return {
      label: "Medium",
      color: "bg-warning-soft text-warning border-2 border-warning/30 font-semibold"
    }
    return {
      label: "Hard",
      color: "bg-destructive-soft text-destructive border-2 border-destructive/30 font-semibold"
    }
  }

  const difficultyBadge = getDifficultyBadge(keyword.difficulty)

  return (
    <AppLayout>
      <div className="container-narrow section-py">
        {/* Back navigation */}
        <Link
          href={project.routes.project}
          className="inline-flex items-center text-sm text-muted-foreground hover:text-primary transition-colors mb-6"
        >
          <ArrowLeft className="mr-2 h-4 w-4" />
          Back to {project.name}
        </Link>

        {/* Page header */}
        <div className="mb-8">
          <h1 className="text-3xl font-display font-bold mb-2">
            Generate Article
          </h1>
          <p className="text-muted-foreground">
            Configure your article settings before generation
          </p>
        </div>

        {/* Keyword info card */}
        <Card className="border-2 mb-6">
          <CardHeader>
            <CardTitle className="text-xl">Target Keyword</CardTitle>
            <CardDescription>This article will target the following keyword</CardDescription>
          </CardHeader>
          <CardContent>
            <div className="space-y-4">
              <div>
                <h3 className="font-mono text-2xl font-bold text-primary mb-3">
                  {keyword.keyword}
                </h3>
              </div>

              <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                <div>
                  <div className="text-sm text-muted-foreground mb-1">Search Volume</div>
                  <div className="text-lg font-semibold">
                    {keyword.volume ? keyword.volume.toLocaleString() : "—"}
                  </div>
                </div>

                <div>
                  <div className="text-sm text-muted-foreground mb-1">Difficulty</div>
                  <Badge className={difficultyBadge.color}>
                    {difficultyBadge.label} ({keyword.difficulty})
                  </Badge>
                </div>

                <div>
                  <div className="text-sm text-muted-foreground mb-1">Opportunity</div>
                  <div className="flex items-center gap-1">
                    <TrendingUp className="h-4 w-4 text-success" />
                    <span className="text-lg font-semibold">{keyword.opportunity}</span>
                  </div>
                </div>

                <div>
                  <div className="text-sm text-muted-foreground mb-1">Intent</div>
                  <Badge className={getIntentBadge(keyword.intent)}>
                    {keyword.intent}
                  </Badge>
                </div>
              </div>
            </div>
          </CardContent>
        </Card>

        {/* Configuration card */}
        <Card className="border-2 mb-6">
          <CardHeader>
            <CardTitle>Article Configuration</CardTitle>
            <CardDescription>Customize your article settings</CardDescription>
          </CardHeader>
          <CardContent className="space-y-6">
            {/* Word count */}
            <div>
              <Label htmlFor="word-count" className="text-base font-semibold mb-3 block">
                Target Word Count
              </Label>
              <select
                id="word-count"
                value={targetWordCount}
                onChange={(e) => setTargetWordCount(parseInt(e.target.value))}
                className="w-full border-2 border-border rounded-lg px-4 py-3 text-base bg-white"
              >
                <option value="1000">1,000 words (Short article)</option>
                <option value="1500">1,500 words (Medium article)</option>
                <option value="2000">2,000 words (Standard article) — Recommended</option>
                <option value="2500">2,500 words (Long article)</option>
                <option value="3000">3,000 words (Comprehensive guide)</option>
              </select>
              <p className="text-sm text-muted-foreground mt-2">
                Longer articles tend to rank better for competitive keywords
              </p>
            </div>

            {/* Info about what happens */}
            <div className="bg-info-soft border-2 border-info/30 rounded-lg p-4">
              <div className="flex gap-3">
                <Info className="h-5 w-5 text-info flex-shrink-0 mt-0.5" />
                <div className="text-sm text-info">
                  <p className="font-semibold mb-1">What happens next:</p>
                  <ul className="list-disc list-inside space-y-1 ml-1">
                    <li>Research top 10 Google results for "{keyword.keyword}"</li>
                    <li>Extract examples, statistics, and common topics</li>
                    <li>Generate comprehensive outline</li>
                    <li>Write {targetWordCount.toLocaleString()}-word article with AI</li>
                    <li>Optimize for SEO and readability</li>
                  </ul>
                  <p className="mt-2 font-medium">⏱️ Takes about 2-4 minutes</p>
                </div>
              </div>
            </div>
          </CardContent>
          <CardFooter className="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4 bg-muted/30">
            {/* Cost info */}
            <div className="flex items-center gap-4">
              <div className="flex items-center gap-2">
                <Coins className="h-5 w-5 text-accent" />
                <div>
                  <div className="text-sm text-muted-foreground">Cost</div>
                  <div className="font-bold">1 credit</div>
                </div>
              </div>
              <div className="flex items-center gap-2">
                <DollarSign className="h-5 w-5 text-muted-foreground" />
                <div>
                  <div className="text-sm text-muted-foreground">Est. API cost</div>
                  <div className="font-semibold">${estimated_cost}</div>
                </div>
              </div>
            </div>

            {/* Credits remaining */}
            <div className="flex items-center gap-2">
              <Target className="h-5 w-5 text-primary" />
              <div>
                <div className="text-sm text-muted-foreground">Credits remaining</div>
                <div className="font-bold text-lg">{user_credits}</div>
              </div>
            </div>
          </CardFooter>
        </Card>

        {/* No credits warning */}
        {user_credits < 1 && (
          <Card className="border-2 border-destructive/30 bg-destructive-soft mb-6">
            <CardContent className="py-4">
              <div className="flex gap-3">
                <AlertCircle className="h-5 w-5 text-destructive flex-shrink-0 mt-0.5" />
                <div>
                  <p className="font-semibold text-destructive mb-1">Out of credits</p>
                  <p className="text-sm text-destructive">
                    You need credits to generate articles.{" "}
                    <Link href={routes.pricing} className="underline font-semibold">
                      Upgrade your plan
                    </Link>{" "}
                    to get more credits.
                  </p>
                </div>
              </div>
            </CardContent>
          </Card>
        )}

        {/* Action buttons */}
        <div className="flex flex-col sm:flex-row gap-3">
          <Link href={project.routes.project} className="flex-1">
            <Button
              variant="outline"
              className="w-full border-2"
              disabled={isSubmitting}
            >
              Cancel
            </Button>
          </Link>
          <Button
            onClick={handleGenerate}
            disabled={user_credits < 1 || isSubmitting}
            className="flex-1 bg-primary hover:bg-primary/90 border-2 shadow-md hover:shadow-lg"
          >
            <FileText className="mr-2 h-5 w-5" />
            {isSubmitting ? "Starting Generation..." : "Generate Article"}
          </Button>
        </div>
      </div>
    </AppLayout>
  )
}
