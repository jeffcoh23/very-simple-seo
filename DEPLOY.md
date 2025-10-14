# 🚀 VerySimpleSEO - Quick Deploy Guide

**Ready to deploy?** Follow this 5-minute quick start.

For complete documentation, see: `docs/deployment_guide.md`

---

## ⚡ Quick Start (5 Commands)

### 1. Get Your API Keys

You need **9 API keys** before deploying:

| Service | Get From | Notes |
|---------|----------|-------|
| OpenAI | https://platform.openai.com/api-keys | For article writing (GPT-4o Mini) |
| Gemini | https://aistudio.google.com/app/apikey | For analysis (Gemini 2.5 Flash) |
| Google Search | https://console.cloud.google.com/apis/credentials | Enable Custom Search API first |
| Google Search CX | https://programmablesearchengine.google.com/ | Create search engine |
| Stripe Secret | https://dashboard.stripe.com/apikeys | **Use sk_live_... for production!** |
| Stripe Webhook | https://dashboard.stripe.com/webhooks | After deployment |
| Resend | https://resend.com/api-keys | For emails |
| Docker Hub | https://hub.docker.com/settings/security | Generate access token |
| Google OAuth | Already configured | In .env file |

### 2. Export Secrets to Environment

Add to `~/.zshrc` or `~/.bashrc`:

```bash
# Docker Hub
export KAMAL_REGISTRY_PASSWORD=dckr_pat_your_token_here

# AI APIs
export OPENAI_API_KEY=sk-proj-your_key_here
export GEMINI_API_KEY=your_key_here

# Google Search
export GOOGLE_SEARCH_KEY=your_key_here
export GOOGLE_SEARCH_CX=your_cx_id_here

# Stripe (PRODUCTION keys!)
export STRIPE_SECRET_KEY=sk_live_your_key_here
export STRIPE_SIGNING_SECRET=whsec_your_secret_here

# Email
export RESEND_API_KEY=re_your_key_here

# Database (if not using Fly.io Postgres)
export DATABASE_URL=postgresql://user:pass@host:5432/verysimpleseo_production
```

Then: `source ~/.zshrc`

### 3. Set Up Hosting

**Option A: Fly.io (Recommended)**

```bash
# Install Fly CLI
brew install flyctl

# Login
fly auth login

# Create app
fly apps create verysimpleseo

# Create PostgreSQL
fly postgres create --name verysimpleseo-db --region sjc

# Attach database (auto-sets DATABASE_URL)
fly postgres attach verysimpleseo-db --app verysimpleseo

# Get server IP
fly ips list
# Copy the IPv4 address
```

**Option B: Hetzner / DigitalOcean / Other VPS**

1. Create a VPS with Ubuntu 22.04 (1GB+ RAM)
2. Install Docker: `curl -fsSL https://get.docker.com | sh`
3. Note the server IP

### 4. Update Configuration

Edit `config/deploy.yml`:

```yaml
# Line 6: Replace with your Docker Hub username
image: yourdockerhubusername/verysimpleseo

# Line 14: Replace with your server IP
servers:
  web:
    - YOUR_SERVER_IP_HERE

# Line 28: Replace with your domain
proxy:
  ssl: true
  host: verysimpleseo.fly.dev  # or your custom domain

# Line 36: Replace with your Docker Hub username
registry:
  username: yourdockerhubusername

# Lines 57-58: Update with your domain
clear:
  APP_HOST: verysimpleseo.fly.dev
  APP_URL: https://verysimpleseo.fly.dev
```

### 5. Deploy!

```bash
# Verify Docker is running
docker ps

# Deploy (first time setup)
kamal setup

# Run migrations
kamal app exec "bin/rails db:migrate"
kamal app exec "bin/rails runner db/seeds/pay_plans.rb"

# Watch logs
kamal app logs -f
```

**Expected output:**
```
Puma starting in cluster mode...
* Listening on http://0.0.0.0:80
SolidQueue supervisor started
```

---

## ✅ Verify Deployment

Visit your app and test:

1. **Sign up** - Create new account
2. **Create project** - Should start keyword research
3. **Wait 42 seconds** - Keywords should appear
4. **Generate article** - Click "Generate" on any keyword
5. **Wait 60 seconds** - Article should complete
6. **Test billing** - Go to /pricing, test checkout

---

## 🔄 Update Deployment (After Code Changes)

```bash
# Deploy updates (zero-downtime)
kamal deploy

# View logs
kamal app logs -f

# Restart if needed
kamal app restart

# Run Rails console
kamal app exec -i "bin/rails console"
```

---

## 🐛 Troubleshooting

### "Docker build failed"

```bash
# Solution: Start Docker Desktop
open -a Docker
# Wait 30 seconds, try again
```

### "Solid Queue not processing jobs"

```bash
# Check if running
kamal app logs | grep "SolidQueue"

# Should see: "SolidQueue supervisor started"

# If not, check env var
kamal app exec "printenv | grep SOLID_QUEUE_IN_PUMA"
# Must show: SOLID_QUEUE_IN_PUMA=true
```

### "Out of memory"

```bash
# Fly.io: Upgrade RAM
fly scale memory 2048 --app verysimpleseo

# Other VPS: Add swap
kamal app exec -i bash
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

### "Database connection failed"

```bash
# Test connection
kamal app exec "bin/rails runner 'puts ActiveRecord::Base.connection.execute(\"SELECT 1\").to_a'"

# Should output: [[1]]

# If fails, check DATABASE_URL
kamal app exec "printenv | grep DATABASE_URL"
```

---

## 📚 Full Documentation

For complete guides, see:

- **`docs/deployment_guide.md`** - Complete walkthrough (500+ lines)
- **`docs/deployment_checklist.md`** - Pre-flight checklist (300+ lines)
- **`docs/phase9_complete.md`** - Phase 9 summary

---

## 💰 Hosting Costs

| Provider | Monthly Cost | RAM | Best For |
|----------|-------------|-----|----------|
| **Fly.io** | $10 | 1GB | MVP (managed DB, easy scaling) |
| **Hetzner** | €4.5 (~$5) | 2GB | Best value (manual setup) |
| **DigitalOcean** | $21 | 1GB | Documentation (managed DB) |

---

## 🎯 Post-Deployment

### Configure Stripe Webhook

1. Go to: https://dashboard.stripe.com/webhooks
2. Click "Add endpoint"
3. URL: `https://your-domain.com/pay/webhooks/stripe`
4. Events: Select all `checkout.*`, `customer.subscription.*`, `invoice.payment_*`
5. Copy signing secret (starts with `whsec_`)
6. Update `.kamal/secrets` with new secret
7. Push new secrets: `kamal env push`

### Monitor Logs

```bash
# All logs
kamal app logs -f

# Errors only
kamal app logs | grep ERROR

# Jobs
kamal app logs | grep "KeywordResearchJob\|ArticleGenerationJob"

# Stripe
kamal app logs | grep "Pay::Webhooks"
```

### Check Background Jobs

```bash
# Count pending jobs
kamal app exec "bin/rails runner 'puts SolidQueue::Job.pending.count'"

# Check for failed jobs
kamal app exec "bin/rails runner 'puts SolidQueue::Job.failed.count'"
```

---

## 🎉 You're Live!

Your VerySimpleSEO app is now deployed and processing keyword research + article generation jobs.

**Next steps:**
1. Test full user flow
2. Invite beta users
3. Monitor logs for first 24 hours
4. Collect feedback
5. Iterate

**Ship it and get users!** 🚀

---

**Questions?** Check `docs/deployment_guide.md` for detailed troubleshooting.
