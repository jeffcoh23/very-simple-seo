import AppLayout from "@/layout/AppLayout"
import { useForm, Link, usePage, router } from "@inertiajs/react"
import { Input } from "@/components/ui/input"
import { Button } from "@/components/ui/button"
import Flash from "@/components/Flash"
import { Card, CardHeader, CardTitle, CardContent, CardDescription } from "@/components/ui/card"
import { Label } from "@/components/ui/label"
import { Badge } from "@/components/ui/badge"
import { Trash2, Star } from "lucide-react"
import { useState } from "react"

export default function Settings({ user, voice_profiles, subscription }) {
  const { routes } = usePage().props;
  const [editingVoice, setEditingVoice] = useState(null);
  const [newVoice, setNewVoice] = useState({ name: "", description: "" });

  const { data: profileData, setData: setProfileData, patch: patchProfile } = useForm({
    user: {
      first_name: user?.first_name || "",
      last_name: user?.last_name || ""
    }
  });

  const { data: passwordData, setData: setPasswordData, patch: patchPassword } = useForm({
    current_password: "",
    user: {
      password: "",
      password_confirmation: ""
    }
  });

  const onProfileSubmit = (e) => {
    e.preventDefault();
    patchProfile(routes.update_settings);
  };

  const onPasswordSubmit = (e) => {
    e.preventDefault();
    patchPassword(routes.update_settings);
  };

  const handleSetDefault = (voiceId) => {
    router.patch(routes.update_settings, {
      default_voice_id: voiceId
    });
  };

  const handleDeleteVoice = (voiceId) => {
    if (!confirm("Are you sure you want to delete this voice profile?")) return;

    router.patch(routes.update_settings, {
      user: {
        voice_profiles_attributes: [{
          id: voiceId,
          _destroy: true
        }]
      }
    });
  };

  const handleCreateVoice = () => {
    if (!newVoice.name.trim()) {
      alert("Please enter a name for the voice profile");
      return;
    }

    router.patch(routes.update_settings, {
      user: {
        voice_profiles_attributes: [{
          name: newVoice.name,
          description: newVoice.description
        }]
      }
    }, {
      onSuccess: () => setNewVoice({ name: "", description: "" })
    });
  };

  const handleUpdateVoice = (voiceId) => {
    if (!editingVoice?.name.trim()) {
      alert("Please enter a name for the voice profile");
      return;
    }

    router.patch(routes.update_settings, {
      user: {
        voice_profiles_attributes: [{
          id: voiceId,
          name: editingVoice.name,
          description: editingVoice.description
        }]
      }
    }, {
      onSuccess: () => setEditingVoice(null)
    });
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
                  <Input
                    value={profileData.user.first_name}
                    onChange={e => setProfileData("user", { ...profileData.user, first_name: e.target.value })}
                  />
                </div>
                <div className="space-y-2">
                  <Label>Last name</Label>
                  <Input
                    value={profileData.user.last_name}
                    onChange={e => setProfileData("user", { ...profileData.user, last_name: e.target.value })}
                  />
                </div>
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
                <Input
                  type="password"
                  value={passwordData.current_password}
                  onChange={e => setPasswordData("current_password", e.target.value)}
                />
              </div>
              <div className="space-y-2">
                <Label>New password</Label>
                <Input
                  type="password"
                  value={passwordData.user.password}
                  onChange={e => setPasswordData("user", { ...passwordData.user, password: e.target.value })}
                />
              </div>
              <div className="space-y-2">
                <Label>Confirm new password</Label>
                <Input
                  type="password"
                  value={passwordData.user.password_confirmation}
                  onChange={e => setPasswordData("user", { ...passwordData.user, password_confirmation: e.target.value })}
                />
              </div>
              <Button type="submit">Update password</Button>
            </form>
          </CardContent>
        </Card>

        <Card className="md:col-span-2">
          <CardHeader>
            <CardTitle>Voice Profiles</CardTitle>
            <CardDescription>
              Manage writing voice profiles. Paste sample text that represents your writing style.
              The AI will learn your tone and apply it to generated articles.
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            {/* Existing Voice Profiles */}
            <div className="space-y-3">
              {voice_profiles?.map((voice) => (
                <div
                  key={voice.id}
                  className="border-2 rounded-lg p-4 space-y-3"
                >
                  {editingVoice?.id === voice.id ? (
                    /* Edit Mode */
                    <div className="space-y-3">
                      <div className="space-y-2">
                        <Label>Name</Label>
                        <Input
                          value={editingVoice.name}
                          onChange={e => setEditingVoice({ ...editingVoice, name: e.target.value })}
                        />
                      </div>
                      <div className="space-y-2">
                        <Label>Sample Text</Label>
                        <textarea
                          value={editingVoice.description}
                          onChange={e => setEditingVoice({ ...editingVoice, description: e.target.value })}
                          placeholder="Paste sample text that represents this writing style..."
                          className="flex min-h-[80px] w-full rounded-md border border-input bg-background px-3 py-2 text-sm"
                          rows={4}
                        />
                      </div>
                      <div className="flex gap-2">
                        <Button size="sm" onClick={() => handleUpdateVoice(voice.id)}>
                          Save
                        </Button>
                        <Button
                          size="sm"
                          variant="outline"
                          onClick={() => setEditingVoice(null)}
                        >
                          Cancel
                        </Button>
                      </div>
                    </div>
                  ) : (
                    /* View Mode */
                    <div>
                      <div className="flex items-start justify-between mb-2">
                        <div className="flex items-center gap-2">
                          <h4 className="font-semibold">{voice.name}</h4>
                          {voice.is_default && (
                            <Badge variant="outline" className="border-accent text-accent">
                              <Star className="h-3 w-3 mr-1 fill-current" />
                              Default
                            </Badge>
                          )}
                        </div>
                        <div className="flex gap-2">
                          {!voice.is_default && (
                            <Button
                              size="sm"
                              variant="ghost"
                              onClick={() => handleSetDefault(voice.id)}
                              title="Set as default"
                            >
                              <Star className="h-4 w-4" />
                            </Button>
                          )}
                          <Button
                            size="sm"
                            variant="ghost"
                            onClick={() => setEditingVoice({ id: voice.id, name: voice.name, description: voice.description })}
                          >
                            Edit
                          </Button>
                          <Button
                            size="sm"
                            variant="ghost"
                            onClick={() => handleDeleteVoice(voice.id)}
                            className="text-destructive hover:text-destructive"
                          >
                            <Trash2 className="h-4 w-4" />
                          </Button>
                        </div>
                      </div>
                      {voice.description && (
                        <p className="text-sm text-muted-foreground line-clamp-2">
                          {voice.description}
                        </p>
                      )}
                    </div>
                  )}
                </div>
              ))}
            </div>

            {/* Create New Voice Profile */}
            <div className="border-2 border-dashed rounded-lg p-4 space-y-3">
              <h4 className="font-semibold">Add New Voice Profile</h4>
              <div className="space-y-2">
                <Label>Name</Label>
                <Input
                  value={newVoice.name}
                  onChange={e => setNewVoice({ ...newVoice, name: e.target.value })}
                  placeholder="e.g., Professional, Casual, Technical"
                />
              </div>
              <div className="space-y-2">
                <Label>Sample Text</Label>
                <textarea
                  value={newVoice.description}
                  onChange={e => setNewVoice({ ...newVoice, description: e.target.value })}
                  placeholder="Paste sample text that represents this writing style..."
                  className="flex min-h-[80px] w-full rounded-md border border-input bg-background px-3 py-2 text-sm"
                  rows={4}
                />
              </div>
              <Button onClick={handleCreateVoice}>Create Voice Profile</Button>
            </div>
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
