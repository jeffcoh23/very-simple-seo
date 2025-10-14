import { Badge } from "@/components/ui/badge";
import { Check } from "lucide-react";

export function PlanSelector({ plans, selectedPlan, onPlanChange }) {
  return (
    <div>
      <h2 className="text-xl font-semibold mb-4">Choose your plan</h2>
      <div className="space-y-3">
        {plans.map((plan) => (
          <div
            key={plan.id}
            className={\`p-4 border rounded-xl cursor-pointer transition-all \${
              selectedPlan === plan.id
                ? "border-primary bg-primary/5 ring-1 ring-primary"
                : "border-border hover:border-primary/50"
            }\`}
            onClick={() => onPlanChange(plan.id)}
          >
            <div className="flex items-center justify-between mb-2">
              <div className="flex items-center gap-3">
                <div
                  className={\`w-4 h-4 rounded-full border-2 flex items-center justify-center \${
                    selectedPlan === plan.id
                      ? "border-primary bg-primary"
                      : "border-border"
                  }\`}
                >
                  {selectedPlan === plan.id && (
                    <Check className="w-2.5 h-2.5 text-white" />
                  )}
                </div>
                <div>
                  <div className="flex items-center gap-2">
                    <span className="font-semibold">{plan.name}</span>
                    {plan.popular && (
                      <Badge variant="secondary">Most Popular</Badge>
                    )}
                  </div>
                </div>
              </div>
              <div className="text-right">
                <div className="text-lg font-bold">
                  \${plan.price}
                  {plan.price > 0 && (
                    <span className="text-sm font-normal text-muted-foreground">
                      /mo
                    </span>
                  )}
                </div>
              </div>
            </div>
            <div className="pl-7">
              <ul className="text-sm text-muted-foreground space-y-1">
                {plan.features.map((feature, idx) => (
                  <li key={idx} className="flex items-center gap-2">
                    <Check className="w-3 h-3 text-green-500 flex-shrink-0" />
                    {feature}
                  </li>
                ))}
              </ul>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
