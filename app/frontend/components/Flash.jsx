import { useState, useEffect } from "react";
import { Alert, AlertTitle, AlertDescription } from "@/components/ui/alert";
import { usePage } from "@inertiajs/react";

export default function Flash() {
  const { flash } = usePage().props;
  const [visible, setVisible] = useState(false);

  useEffect(() => {
    if (flash?.alert || flash?.notice) {
      setVisible(true);
      const timer = setTimeout(() => {
        setVisible(false);
      }, 3000);
      return () => clearTimeout(timer);
    }
  }, [flash]);

  if (!visible || (!flash?.alert && !flash?.notice)) return null;

  return (
    <div className="fixed top-4 left-1/2 -translate-x-1/2 w-[90%] max-w-sm z-50 transition-opacity duration-300">
      <Alert>
        <AlertTitle>{flash.alert ? "Error" : "Notice"}</AlertTitle>
        <AlertDescription>{flash.alert || flash.notice}</AlertDescription>
      </Alert>
    </div>
  );
}
