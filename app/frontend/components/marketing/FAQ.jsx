import { Accordion, AccordionItem, AccordionTrigger, AccordionContent } from "@/components/ui/accordion"
export default function FAQ({ items = [] }) {
  return (
    <section id="faq" className="section-py">
      <div className="container max-w-3xl">
        <h3 className="text-2xl md:text-3xl font-display font-bold text-center">FAQ</h3>
        <Accordion type="single" collapsible className="mt-6">
          {items.map((q, i) => (
            <AccordionItem key={i} value={`faq-${i}`} className="border-b-2">
              <AccordionTrigger className="text-left hover:text-primary transition-colors">{q.question}</AccordionTrigger>
              <AccordionContent className="text-muted-foreground">{q.answer}</AccordionContent>
            </AccordionItem>
          ))}
        </Accordion>
      </div>
    </section>
  )
}
