import AppLayout from "@/layout/AppLayout"
import { useForm, Link, usePage } from "@inertiajs/react"
import { Input } from "@/components/ui/input"
import { Button } from "@/components/ui/button"
import Flash from "@/components/Flash"
import { Card, CardHeader, CardTitle, CardContent, CardDescription } from "@/components/ui/card"
import { Label } from "@/components/ui/label"

export default function Settings({ user, subscription }) {
  const { routes } = usePage().props;
  const { data: profileData, setData: setProfileData, patch: patchProfile } = useForm({
    first_name: user?.first_name || "",
    last_name: user?.last_name || "",
    voice_profile: user?.voice_profile || ""
  });

  const { data: passwordData, setData: setPasswordData, patch: patchPassword } = useForm({
    current_password: "",
    password: "",
    password_confirmation: ""
  });

  const onProfileSubmit = (e) => {
    e.preventDefault();
    patchProfile("/settings/profile")
  };

  const onPasswordSubmit = (e) => {
    e.preventDefault();
    patchPassword("/settings/password");
  };

  return (
    <AppLayout>
      <Flash />
      <h2 className="text-2xl font-display font-bold mb-6">Settings</h2>
      <div className="grid md:grid-cols-2 gap-8">
        <Card className="md:col-span-2">
          <CardHeader>
            <CardTitle>Profile</CardTitle>
          </CardHeader>
          <CardContent>
            <form onSubmit={onProfileSubmit} className="space-y-4">
              <div className="grid md:grid-cols-2 gap-4">
                <div className="space-y-2">
                  <Label>First name</Label>
                  <Input value={profileData.first_name} onChange={e => setProfileData("first_name", e.target.value)} />
                </div>
                <div className="space-y-2">
                  <Label>Last name</Label>
                  <Input value={profileData.last_name} onChange={e => setProfileData("last_name", e.target.value)} />
                </div>
              </div>

              <div className="space-y-2">
                <Label htmlFor="voice_profile">Writing Voice Profile</Label>
                <textarea
                  id="voice_profile"
                  value={profileData.voice_profile}
                  onChange={e => setProfileData("voice_profile", e.target.value)}
                  placeholder="Paste sample text that represents your writing style (tweets, blog posts, etc.). The AI will learn your tone and apply it to generated articles."
                  className="flex min-h-[120px] w-full rounded-md border border-input bg-background px-3 py-2 text-base ring-offset-background placeholder:text-muted-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring focus-visible:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50 md:text-sm"
                  rows={6}
                />
                <p className="text-sm text-muted-foreground">
                  Copy any text that captures your writing style. AI will use this to match your tone in articles.
                </p>
              </div>

              <Button type="submit">Save Profile</Button>
            </form>
          </CardContent>
        </Card>

        <Card>
          <CardHeader><CardTitle>Password</CardTitle></CardHeader>
          <CardContent>
            <form onSubmit={onPasswordSubmit} className="space-y-3">
              <div className="space-y-2">
                <Label>Current password</Label>
                <Input type="password" value={passwordData.current_password} onChange={e => setPasswordData("current_password", e.target.value)} />
              </div>
              <div className="space-y-2">
                <Label>New password</Label>
                <Input type="password" value={passwordData.password} onChange={e => setPasswordData("password", e.target.value)} />
              </div>
              <div className="space-y-2">
                <Label>Confirm new password</Label>
                <Input type="password" value={passwordData.password_confirmation} onChange={e => setPasswordData("password_confirmation", e.target.value)} />
              </div>
              <Button type="submit">Update password</Button>
            </form>
          </CardContent>
        </Card>

        <Card className="md:col-span-2">
          <CardHeader><CardTitle>Subscription</CardTitle></CardHeader>
          <CardContent className="text-sm">
            {subscription ? (
              <div className="space-y-2">
                <div>Status: <b>{subscription.status}</b></div>
                <div>Plan: <b>{subscription.plan}</b></div>
                {subscription.on_grace_period && subscription.ends_at && (
                  <div>Ends at: {new Date(subscription.ends_at).toLocaleString()}</div>
                )}
                <div className="mt-3">
                  <Link href={routes.billing_portal}><Button variant="outline">Manage billing</Button></Link>
                </div>
              </div>
            ) : (
              <div>
                <p className="text-muted-foreground mb-3">No active subscription.</p>
                <Link href={routes.pricing}><Button>View plans</Button></Link>
              </div>
            )}
          </CardContent>
        </Card>
      </div>
    </AppLayout>
  )
}
