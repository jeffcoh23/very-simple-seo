import { useForm, Link, usePage } from "@inertiajs/react";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { Card, CardHeader, CardTitle, CardContent, CardFooter } from "@/components/ui/card";
import { Label } from "@/components/ui/label";
import AuthLayout from "@/layout/AuthLayout";

export default function Login() {
  const { routes } = usePage().props;
  const { data, setData, post, processing } = useForm({ email_address: "", password: "" });
  const handleSubmit = (e) => { e.preventDefault(); post("/sign_in"); };

  return (
    <AuthLayout>
      <div className="mx-auto max-w-md">
        <Card className="rounded-2xl border-2 shadow-emphasis">
          <CardHeader>
            <CardTitle className="text-2xl font-display">Log in</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="space-y-2">
              <Label>Email</Label>
              <Input placeholder="you@example.com" value={data.email_address} onChange={e => setData("email_address", e.target.value)} />
            </div>
            <div className="space-y-2">
              <Label>Password</Label>
              <Input type="password" placeholder="••••••••" value={data.password} onChange={e => setData("password", e.target.value)} />
            </div>
          </CardContent>
          <CardFooter className="flex flex-col gap-3">
            <Button className="w-full border-2 shadow-md hover:shadow-lg" size="lg" disabled={processing} onClick={handleSubmit}>Log in</Button>
            <Button variant="outline" className="w-full border-2" size="lg" onClick={() => window.location.href = "/auth/google_oauth2"}>Sign in with Google</Button>
            <p className="text-sm text-muted-foreground">No account? <Link href={routes.signup} className="text-primary hover:text-primary/80 underline">Sign up</Link></p>
          </CardFooter>
        </Card>
      </div>
    </AuthLayout>
  );
}
