import { useState } from "react"
import { router, usePage } from "@inertiajs/react"
import { Button } from "@/components/ui/button"
import { FileText } from "lucide-react"

export default function ArticleGenerateForm({ keyword, createArticleUrl, hasCredits }) {
  const [targetWordCount, setTargetWordCount] = useState(2000)
  const [isSubmitting, setIsSubmitting] = useState(false)

  const handleSubmit = (e) => {
    e.preventDefault()

    if (!hasCredits) return

    setIsSubmitting(true)

    router.post(
      createArticleUrl,
      {
        keyword_id: keyword.id,
        target_word_count: targetWordCount
      },
      {
        onFinish: () => setIsSubmitting(false)
      }
    )
  }

  return (
    <form onSubmit={handleSubmit} className="inline-flex gap-2">
      <select
        value={targetWordCount}
        onChange={(e) => setTargetWordCount(parseInt(e.target.value))}
        className="text-sm border-2 rounded px-2 py-1"
        disabled={!hasCredits || isSubmitting}
      >
        <option value="1000">1000 words</option>
        <option value="1500">1500 words</option>
        <option value="2000">2000 words</option>
        <option value="2500">2500 words</option>
        <option value="3000">3000 words</option>
      </select>
      <Button
        type="submit"
        size="sm"
        className="border-2 shadow-md hover:shadow-lg"
        disabled={!hasCredits || isSubmitting}
      >
        <FileText className="mr-2 h-4 w-4" />
        {isSubmitting ? "Starting..." : "Generate"}
      </Button>
    </form>
  )
}
