import { useForm, Link, usePage } from "@inertiajs/react";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { Card, CardHeader, CardTitle, CardContent, CardFooter } from "@/components/ui/card";
import { Label } from "@/components/ui/label";
import { Badge } from "@/components/ui/badge";
import AuthLayout from "@/layout/AuthLayout";

export default function Signup({ plan = "free", plans = [] }) {
  const { routes } = usePage().props;
  const { data, setData, post, processing } = useForm({
    first_name: "",
    last_name: "",
    email_address: "",
    password: "",
    password_confirmation: "",
    plan: plan
  });

  const handleSubmit = (e) => {
    e.preventDefault();
    post("/sign_up");
  };

  const handleGoogleSignup = () => {
    const state = JSON.stringify({ plan: data.plan });
    window.location.href = `/auth/google_oauth2?state=${encodeURIComponent(state)}`;
  };

  return (
    <AuthLayout>
      <div className="mx-auto max-w-2xl">

            {/* Plan Selection */}
            {plans.length > 0 && (
              <div className="mb-8">
                <h3 className="text-lg font-semibold mb-4">Choose your plan</h3>
                <div className="grid md:grid-cols-3 gap-4">
                  {plans.map((p) => (
                    <Card
                      key={p.id}
                      className={`cursor-pointer rounded-xl border-2 transition-all ${data.plan === p.id ? 'ring-2 ring-primary border-primary' : 'hover:border-primary'}`}
                      onClick={() => setData("plan", p.id)}
                    >
                      <CardContent className="p-4">
                        <div className="flex items-start justify-between mb-2">
                          <h4 className="font-semibold">{p.name}</h4>
                          {p.popular && <Badge className="bg-accent text-accent-foreground border-2 border-accent/30">Popular</Badge>}
                        </div>
                        <p className="text-2xl font-bold">
                          ${p.price}<span className="text-sm font-normal text-muted-foreground">/mo</span>
                        </p>
                      </CardContent>
                    </Card>
                  ))}
                </div>
              </div>
            )}

            <Card className="rounded-2xl border-2 shadow-emphasis">
              <CardHeader>
                <CardTitle className="text-2xl font-display">Create account</CardTitle>
              </CardHeader>
              <CardContent className="space-y-4">
                <div className="grid md:grid-cols-2 gap-4">
                  <div className="space-y-2">
                    <Label>First name</Label>
                    <Input placeholder="John" value={data.first_name} onChange={e => setData("first_name", e.target.value)} />
                  </div>
                  <div className="space-y-2">
                    <Label>Last name</Label>
                    <Input placeholder="Doe" value={data.last_name} onChange={e => setData("last_name", e.target.value)} />
                  </div>
                </div>
                <div className="space-y-2">
                  <Label>Email</Label>
                  <Input placeholder="you@example.com" value={data.email_address} onChange={e => setData("email_address", e.target.value)} />
                </div>
                <div className="space-y-2">
                  <Label>Password</Label>
                  <Input type="password" placeholder="••••••••" value={data.password} onChange={e => setData("password", e.target.value)} />
                </div>
                <div className="space-y-2">
                  <Label>Confirm password</Label>
                  <Input type="password" placeholder="••••••••" value={data.password_confirmation} onChange={e => setData("password_confirmation", e.target.value)} />
                </div>
              </CardContent>
              <CardFooter className="flex flex-col gap-3">
                <Button className="w-full border-2 shadow-md hover:shadow-lg" size="lg" onClick={handleSubmit} disabled={processing}>Sign up</Button>
                <Button variant="outline" className="w-full border-2" size="lg" onClick={handleGoogleSignup}>Sign up with Google</Button>
                <p className="text-sm text-muted-foreground">Already have an account? <Link href={routes.login} className="text-primary hover:text-primary/80 underline">Log in</Link></p>
              </CardFooter>
            </Card>
      </div>
    </AuthLayout>
  );
}
