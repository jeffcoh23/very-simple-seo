import { Alert, AlertDescription } from "@/components/ui/alert"
import { Button } from "@/components/ui/button"
import { X } from "lucide-react"

/**
 * Standardized Banner Component for VerySimpleSEO
 *
 * Usage:
 * <Banner
 *   type="warning"
 *   icon={MailWarning}
 *   message="Your message here"
 *   action={{ label: "Action", onClick: () => {} }}
 *   onDismiss={() => {}}
 * />
 */

const bannerStyles = {
  info: {
    container: "bg-info-soft border-b-2 border-info/30",
    alert: "border-info/30 bg-transparent",
    icon: "text-info",
    text: "text-foreground",
    button: "border-2 border-info/30 hover:bg-info-soft",
  },
  warning: {
    container: "bg-warning-soft border-b-2 border-warning/30",
    alert: "border-warning/30 bg-transparent",
    icon: "text-warning",
    text: "text-foreground",
    button: "border-2 border-warning/30 hover:bg-warning-soft",
  },
  success: {
    container: "bg-success-soft border-b-2 border-success/30",
    alert: "border-success/30 bg-transparent",
    icon: "text-success",
    text: "text-foreground",
    button: "border-2 border-success/30 hover:bg-success-soft",
  },
  destructive: {
    container: "bg-destructive-soft border-b-2 border-destructive/30",
    alert: "border-destructive/30 bg-transparent",
    icon: "text-destructive",
    text: "text-foreground",
    button: "border-2 border-destructive/30 hover:bg-destructive-soft",
  },
}

export function Banner({
  type = "info",
  icon: Icon,
  message,
  action,
  onDismiss,
  className = ""
}) {
  const styles = bannerStyles[type] || bannerStyles.info

  return (
    <div className={`${styles.container} ${className}`}>
      <div className="container py-3">
        <Alert className={styles.alert}>
          <div className="flex items-center gap-3">
            {Icon && <Icon className={`h-5 w-5 ${styles.icon} flex-shrink-0`} />}
            <AlertDescription className="flex items-center justify-between flex-1 gap-4">
              <span className={`${styles.text} font-medium`}>
                {message}
              </span>
              <div className="flex items-center gap-2 flex-shrink-0">
                {action && (
                  <Button
                    variant="outline"
                    size="sm"
                    onClick={action.onClick}
                    disabled={action.disabled}
                    className={styles.button}
                  >
                    {action.label}
                  </Button>
                )}
                {onDismiss && (
                  <Button
                    variant="ghost"
                    size="icon"
                    onClick={onDismiss}
                    className="h-8 w-8 hover:bg-transparent"
                  >
                    <X className={`h-4 w-4 ${styles.icon}`} />
                  </Button>
                )}
              </div>
            </AlertDescription>
          </div>
        </Alert>
      </div>
    </div>
  )
}
