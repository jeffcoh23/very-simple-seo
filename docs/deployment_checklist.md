# VerySimpleSEO - Pre-Deployment Checklist

Use this checklist to ensure you're ready to deploy VerySimpleSEO to production.

---

## ✅ Before You Deploy

### 1. API Keys & Credentials

- [ ] **OpenAI API Key** (GPT-4o Mini for article writing)
  - Get from: https://platform.openai.com/api-keys
  - Ensure billing is enabled
  - Add $10+ credit for testing

- [ ] **Gemini API Key** (Gemini 2.5 Flash for analysis)
  - Get from: https://aistudio.google.com/app/apikey
  - Free tier should be sufficient for MVP

- [ ] **Google Custom Search API Key**
  - Enable Custom Search API: https://console.cloud.google.com/apis/library/customsearch.googleapis.com
  - Create credentials: https://console.cloud.google.com/apis/credentials
  - Note: 100 free queries/day, then $5 per 1000 queries

- [ ] **Google Custom Search Engine ID (CX)**
  - Create search engine: https://programmablesearchengine.google.com/
  - Set to search entire web
  - Copy Search Engine ID

- [ ] **Stripe Secret Key (PRODUCTION)**
  - Get from: https://dashboard.stripe.com/apikeys
  - ⚠️ **Use `sk_live_...` not `sk_test_...`**
  - Test mode won't charge real cards!

- [ ] **Stripe Webhook Signing Secret**
  - Create webhook: https://dashboard.stripe.com/webhooks
  - URL: `https://your-domain.com/pay/webhooks/stripe`
  - Select events: `checkout.session.completed`, `customer.subscription.*`, `invoice.payment_*`
  - Copy signing secret (starts with `whsec_`)

- [ ] **Resend API Key** (for production emails)
  - Get from: https://resend.com/api-keys
  - Verify your sending domain (or use resend.dev for testing)

- [ ] **Docker Hub Account**
  - Create account: https://hub.docker.com/signup
  - Generate access token: https://hub.docker.com/settings/security
  - Copy token (you won't see it again!)

---

### 2. Server Setup

Choose your hosting provider:

**Option A: Fly.io (Recommended for MVP)**
- [ ] Install Fly CLI: `brew install flyctl`
- [ ] Login: `fly auth login`
- [ ] Create app: `fly apps create verysimpleseo`
- [ ] Create PostgreSQL: `fly postgres create --name verysimpleseo-db`
- [ ] Attach database: `fly postgres attach verysimpleseo-db --app verysimpleseo`
- [ ] Get server IP: `fly ips list`

**Option B: Hetzner VPS (Best value)**
- [ ] Create account: https://www.hetzner.com/cloud
- [ ] Create CX11 server (€4.5/month, 2GB RAM)
- [ ] Choose Ubuntu 22.04
- [ ] Add SSH key
- [ ] Note server IP address
- [ ] Install Docker: `ssh root@your-ip`, then `curl -fsSL https://get.docker.com | sh`

**Option C: DigitalOcean**
- [ ] Create Droplet: https://cloud.digitalocean.com/droplets/new
- [ ] Choose Basic plan ($6/month, 1GB RAM)
- [ ] Ubuntu 22.04
- [ ] Add SSH key
- [ ] Note droplet IP
- [ ] Docker pre-installed ✅

---

### 3. Update Configuration Files

**Update `config/deploy.yml`:**
- [ ] Line 6: Replace `yourdockerhubusername` with your Docker Hub username
- [ ] Line 14: Replace `YOUR_SERVER_IP_HERE` with your server's IP
- [ ] Line 28: Replace `verysimpleseo.fly.dev` with your domain
- [ ] Line 36: Replace `yourdockerhubusername` with your Docker Hub username
- [ ] Line 57-58: Update `APP_HOST` and `APP_URL` with your domain

**Verify `.kamal/secrets`:**
- [ ] File is executable: `chmod +x .kamal/secrets`
- [ ] Not committed to git (check `.gitignore` includes `.kamal/secrets`)

---

### 4. Export Environment Variables

Add these to your `~/.zshrc` or `~/.bashrc`:

```bash
# Docker Hub
export KAMAL_REGISTRY_PASSWORD=dckr_pat_...

# Database (if not using Fly.io Postgres, which auto-sets this)
export DATABASE_URL=postgresql://user:pass@host:5432/verysimpleseo_production

# AI APIs
export OPENAI_API_KEY=sk-proj-...
export GEMINI_API_KEY=...

# Google Search
export GOOGLE_SEARCH_KEY=...
export GOOGLE_SEARCH_CX=...

# Stripe (PRODUCTION keys!)
export STRIPE_SECRET_KEY=sk_live_...
export STRIPE_SIGNING_SECRET=whsec_...

# Email
export RESEND_API_KEY=re_...
```

Then reload: `source ~/.zshrc`

**Verify exports:**
- [ ] `echo $KAMAL_REGISTRY_PASSWORD` - should show Docker token
- [ ] `echo $OPENAI_API_KEY` - should show OpenAI key
- [ ] `echo $STRIPE_SECRET_KEY` - should start with `sk_live_` (not `sk_test_`)

---

### 5. Test Local Docker Build

Before deploying, ensure Docker build works:

```bash
# Start Docker Desktop
open -a Docker

# Wait for Docker to start, then test build
docker build -t verysimpleseo-test .

# If successful, you should see:
# => exporting to image
# => => naming to docker.io/library/verysimpleseo-test
```

**Common issues:**
- ❌ "Cannot connect to Docker daemon" → Start Docker Desktop
- ❌ "npm install failed" → Check `package.json` for syntax errors
- ❌ "bundle install failed" → Check `Gemfile` for missing gems

---

## 🚀 Deployment Commands

### Initial Setup (First Deployment)

```bash
# 1. Set up Kamal on your server (installs Docker, configures environment)
kamal setup

# This will:
# - Install Docker on your server
# - Build your Docker image
# - Push to Docker Hub
# - Pull on server and start
# - Run database migrations

# 2. Run database seeds
kamal app exec "bin/rails db:migrate"
kamal app exec "bin/rails runner db/seeds/pay_plans.rb"

# 3. Check logs
kamal app logs -f
```

**Expected output:**
```
Puma starting in cluster mode...
* Environment: production
* Process workers: 1
* Threads: 5 - 5
* Listening on http://0.0.0.0:80
SolidQueue supervisor started
```

---

### Verify Deployment

Visit your app and test:

1. **Sign Up**
   - [ ] Can create account with email + password
   - [ ] Receive verification email

2. **Create Project**
   - [ ] Can create new project
   - [ ] Keyword research starts automatically
   - [ ] See real-time progress updates

3. **Keywords**
   - [ ] Keywords appear after ~42 seconds
   - [ ] Can click "Generate Article"

4. **Article Generation**
   - [ ] Article generates in ~60 seconds
   - [ ] Can view completed article
   - [ ] Can export as markdown/HTML

5. **Billing**
   - [ ] Visit `/pricing`
   - [ ] Click "Upgrade to Pro"
   - [ ] Stripe checkout opens
   - [ ] Test card: `4242 4242 4242 4242`, any future date, any CVC
   - [ ] After payment, credits increase

6. **Background Jobs**
   - [ ] Check logs: `kamal app logs | grep "KeywordResearchJob"`
   - [ ] Should see jobs completing

---

### Post-Deployment Configuration

**Stripe Webhook:**
- [ ] Go to https://dashboard.stripe.com/webhooks
- [ ] Click "Add endpoint"
- [ ] URL: `https://your-domain.com/pay/webhooks/stripe`
- [ ] Select events: `checkout.session.completed`, `customer.subscription.*`, `invoice.payment_*`
- [ ] Copy signing secret
- [ ] Update `.kamal/secrets` with new `STRIPE_SIGNING_SECRET`
- [ ] Push new secrets: `kamal env push`

**DNS (if using custom domain):**
- [ ] Add A record: `@` → `your-server-ip`
- [ ] Add AAAA record (if IPv6): `@` → `your-server-ipv6`
- [ ] Wait for DNS propagation (up to 24 hours)
- [ ] Update `config/deploy.yml` with new domain
- [ ] Redeploy: `kamal deploy`

---

## 🔄 Common Deployment Commands

```bash
# Deploy updates (after code changes)
kamal deploy

# View logs (real-time)
kamal app logs -f

# Restart app
kamal app restart

# Run Rails console
kamal app exec -i "bin/rails console"

# Run database migrations
kamal app exec "bin/rails db:migrate"

# Check app status
kamal app details

# Update environment variables only (no rebuild)
kamal env push

# SSH into server
kamal app exec -i bash

# Check Solid Queue workers
kamal app exec "bin/rails runner 'puts SolidQueue::Worker.count'"

# Force rebuild and deploy
kamal deploy --force
```

---

## 🐛 Troubleshooting

### Docker Build Fails

**Error:** `Cannot connect to Docker daemon`
```bash
# Solution: Start Docker Desktop
open -a Docker
# Wait 30 seconds, then try again
```

**Error:** `npm install failed`
```bash
# Solution: Test locally first
npm install
npm run build
# If it works locally, Docker should work too
```

### Deployment Hangs at "Pushing image"

**Problem:** Large image taking too long to push
```bash
# Solution: Check Docker image size
docker images | grep verysimpleseo

# If >1GB, optimize Dockerfile (already done ✅)
```

### App Crashes After Deployment

**Error:** `Puma startup failed`
```bash
# Check logs for specific error
kamal app logs | tail -50

# Common issues:
# - Missing DATABASE_URL: Check .kamal/secrets
# - Missing RAILS_MASTER_KEY: Verify config/master.key exists
# - Out of memory: Upgrade server to 2GB RAM
```

### Solid Queue Not Processing Jobs

```bash
# Check if Solid Queue is running
kamal app logs | grep "SolidQueue"

# Should see: "SolidQueue supervisor started"

# If not, verify env var:
kamal app exec "printenv | grep SOLID_QUEUE_IN_PUMA"
# Should show: SOLID_QUEUE_IN_PUMA=true
```

### Database Connection Failed

```bash
# Test database connection
kamal app exec "bin/rails runner 'puts ActiveRecord::Base.connection.execute(\"SELECT 1\").to_a'"

# Should output: [[1]]

# If fails, check DATABASE_URL:
kamal app exec "printenv | grep DATABASE_URL"
```

---

## 📊 Monitoring

### Watch Logs in Real-Time

```bash
# All logs
kamal app logs -f

# Filter for errors
kamal app logs | grep ERROR

# Filter for jobs
kamal app logs | grep "KeywordResearchJob\|ArticleGenerationJob"

# Filter for Stripe events
kamal app logs | grep "Pay::Webhooks"
```

### Check Resource Usage

```bash
# App container stats
kamal app details

# Shows:
# - CPU usage
# - Memory usage
# - Uptime
# - Container status
```

### Monitor Background Jobs

```bash
# Count pending jobs
kamal app exec "bin/rails runner 'puts SolidQueue::Job.pending.count'"

# Check for failed jobs
kamal app exec "bin/rails runner 'puts SolidQueue::Job.failed.count'"

# View failed jobs
kamal app exec "bin/rails runner 'SolidQueue::Job.failed.limit(5).each { |j| puts \"#{j.class_name} - #{j.arguments}\" }'"
```

---

## 🎉 Deployment Complete!

Your VerySimpleSEO app should now be live and processing keyword research + article generation jobs.

**Next steps:**
1. Monitor logs for first 24 hours
2. Test full user flow end-to-end
3. Invite beta users
4. Collect feedback
5. Iterate and improve

**Ship it!** 🚀

---

## 📚 Additional Resources

- **Kamal Handbook:** https://kamal-deploy.org
- **Fly.io Docs:** https://fly.io/docs
- **Solid Queue:** https://github.com/rails/solid_queue
- **Troubleshooting:** See `docs/deployment_guide.md` for detailed guides

---

**Need help?** Check logs first with `kamal app logs -f`

Most issues can be diagnosed from error messages in the logs.
