import { Banner } from "@/components/ui/banner";
import { usePage, router } from "@inertiajs/react";
import { MailWarning } from "lucide-react";

export default function EmailVerificationBanner() {
  const { auth, routes } = usePage().props;

  if (!auth?.user || auth.user.email_verified) return null;

  const handleResend = () => {
    router.post(routes.resend_email_verification || "/email_verification");
  };

  return (
    <Banner
      type="warning"
      icon={MailWarning}
      message="Please verify your email address to access all features."
      action={{
        label: "Resend verification email",
        onClick: handleResend
      }}
    />
  );
}
