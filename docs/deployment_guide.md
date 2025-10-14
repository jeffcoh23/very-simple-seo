# VerySimpleSEO Deployment Guide

## Overview

This guide covers deploying VerySimpleSEO using **Kamal 2** (Rails 8's built-in deployment tool). Kamal allows you to deploy to any server with Docker installed, making it flexible for various hosting providers.

---

## 🎯 Deployment Options

You can deploy VerySimpleSEO to any of these providers:

1. **Fly.io** (Recommended for MVP) - $5/month VM + managed PostgreSQL
2. **Hetzner** - €4.5/month VPS (great value)
3. **DigitalOcean** - $6/month Droplet
4. **Any VPS** with Docker support

This guide focuses on **Fly.io** as recommended in the roadmap, but the Kamal configuration works with any provider.

---

## 📋 Pre-Deployment Checklist

### 1. Required API Keys & Credentials

Before deploying, ensure you have:

- ✅ **OpenAI API Key** (for GPT-4o Mini article writing)
- ✅ **Gemini API Key** (for Gemini 2.5 Flash analysis)
- ✅ **Google Custom Search API Key** (for SERP research)
- ✅ **Google Custom Search Engine ID (CX)** (for SERP research)
- ✅ **Stripe Secret Key** (production mode)
- ✅ **Stripe Webhook Secret** (from Stripe dashboard)
- ✅ **Resend API Key** (for production emails)
- ✅ **Docker Hub account** (or other container registry)
- ✅ **Rails Master Key** (already in `config/master.key`)

**Optional but recommended:**
- Google Ads API credentials (for real keyword metrics)
- Custom domain name

### 2. Server Requirements

Minimum specs for initial deployment:
- **CPU:** 1 shared vCPU (2 vCPU recommended)
- **RAM:** 1GB minimum (2GB recommended for Solid Queue)
- **Storage:** 10GB
- **OS:** Ubuntu 22.04 or newer with Docker installed

---

## 🚀 Deployment Steps

### Step 1: Set Up Fly.io (Recommended)

```bash
# Install Fly CLI
brew install flyctl

# Login to Fly.io
fly auth login

# Create a new app (don't launch yet, just reserve the name)
fly apps create verysimpleseo
```

### Step 2: Create PostgreSQL Database

VerySimpleSEO uses PostgreSQL for:
- Application data (users, projects, keywords, articles)
- Solid Queue (background jobs)
- Solid Cable (WebSocket connections)
- Solid Cache (caching)

```bash
# Create a PostgreSQL cluster on Fly.io
fly postgres create --name verysimpleseo-db --region sjc

# Attach the database to your app
fly postgres attach verysimpleseo-db --app verysimpleseo

# This creates a DATABASE_URL environment variable automatically
```

**For other providers (Hetzner, DigitalOcean, etc.):**
- Set up PostgreSQL 14+ on your server
- Create database: `createdb verysimpleseo_production`
- Store connection string in `.kamal/secrets` as `DATABASE_URL`

### Step 3: Configure Docker Registry

Kamal needs to push your Docker image to a registry. Use Docker Hub (free):

```bash
# Create Docker Hub account at https://hub.docker.com

# Generate an access token:
# 1. Go to https://hub.docker.com/settings/security
# 2. Click "New Access Token"
# 3. Name: "kamal-deploy"
# 4. Copy the token (you won't see it again!)

# Store token in environment
export KAMAL_REGISTRY_PASSWORD=your_docker_hub_token_here
```

### Step 4: Update Kamal Configuration

Edit `config/deploy.yml`:

```yaml
# Name of your application
service: verysimpleseo

# Docker image (replace 'yourdockerhubusername' with your actual username)
image: yourdockerhubusername/verysimpleseo

# Deploy to Fly.io machines (or your VPS IP addresses)
servers:
  web:
    - your-fly-machine-ip-here  # Get this from: fly ips list

# SSL via Fly.io proxy (or Let's Encrypt)
proxy:
  ssl: true
  host: verysimpleseo.fly.dev  # Or your custom domain

# Docker Hub credentials
registry:
  username: yourdockerhubusername
  password:
    - KAMAL_REGISTRY_PASSWORD

# Environment variables for production
env:
  secret:
    - RAILS_MASTER_KEY
    - DATABASE_URL          # From fly postgres attach
    - OPENAI_API_KEY
    - GEMINI_API_KEY
    - GOOGLE_SEARCH_KEY
    - GOOGLE_SEARCH_CX
    - STRIPE_SECRET_KEY
    - STRIPE_SIGNING_SECRET
    - RESEND_API_KEY
  clear:
    APP_HOST: verysimpleseo.fly.dev
    APP_URL: https://verysimpleseo.fly.dev
    RAILS_ENV: production
    RAILS_LOG_LEVEL: info

    # Run Solid Queue inside Puma (single server setup)
    SOLID_QUEUE_IN_PUMA: true

    # Job concurrency (adjust based on server size)
    # WEB_CONCURRENCY: 2
    # JOB_CONCURRENCY: 3

# Persistent storage for user uploads (if needed in future)
volumes:
  - "verysimpleseo_storage:/rails/storage"

# Docker build configuration
builder:
  arch: amd64
```

### Step 5: Configure Secrets

Edit `.kamal/secrets` to pull secrets from environment:

```bash
#!/bin/bash

# Docker registry token (set in your local environment)
export KAMAL_REGISTRY_PASSWORD=$KAMAL_REGISTRY_PASSWORD

# Rails master key (auto-generated, don't change)
export RAILS_MASTER_KEY=$(cat config/master.key)

# Database (if not using Fly Postgres, add manually)
# export DATABASE_URL="postgresql://user:password@host:5432/verysimpleseo_production"

# API Keys (set these in your environment before deploying)
export OPENAI_API_KEY=$OPENAI_API_KEY
export GEMINI_API_KEY=$GEMINI_API_KEY
export GOOGLE_SEARCH_KEY=$GOOGLE_SEARCH_KEY
export GOOGLE_SEARCH_CX=$GOOGLE_SEARCH_CX

# Stripe (production keys)
export STRIPE_SECRET_KEY=$STRIPE_SECRET_KEY
export STRIPE_SIGNING_SECRET=$STRIPE_SIGNING_SECRET

# Email via Resend
export RESEND_API_KEY=$RESEND_API_KEY
```

**Security Note:** Never commit API keys to git. Add them to your shell profile or use a password manager.

### Step 6: Set Environment Variables Locally

Before deploying, export all production secrets to your local environment:

```bash
# Add to ~/.zshrc or ~/.bashrc (use production keys, not test keys!)
export KAMAL_REGISTRY_PASSWORD=your_docker_hub_token
export OPENAI_API_KEY=sk-proj-...
export GEMINI_API_KEY=...
export GOOGLE_SEARCH_KEY=...
export GOOGLE_SEARCH_CX=...
export STRIPE_SECRET_KEY=sk_live_...  # Use LIVE keys for production!
export STRIPE_SIGNING_SECRET=whsec_...  # From Stripe webhook settings
export RESEND_API_KEY=re_...

# Reload shell
source ~/.zshrc
```

### Step 7: Initial Deployment

```bash
# Set up Kamal on the server (installs Docker, creates directories)
kamal setup

# This will:
# 1. Install Docker on your server (if needed)
# 2. Build your Docker image locally
# 3. Push to Docker Hub
# 4. Pull on server and start container
# 5. Run database migrations
# 6. Start the app with Thruster (HTTP/2 proxy)
```

If `kamal setup` succeeds, your app is live! 🎉

### Step 8: Run Database Migrations & Seeds

```bash
# Run migrations
kamal app exec "bin/rails db:migrate"

# Seed Stripe plans
kamal app exec "bin/rails runner db/seeds/pay_plans.rb"

# Verify the app is running
kamal app logs
```

### Step 9: Configure Stripe Webhooks

1. Go to Stripe Dashboard → Developers → Webhooks
2. Click "Add endpoint"
3. URL: `https://verysimpleseo.fly.dev/pay/webhooks/stripe`
4. Select events:
   - `checkout.session.completed`
   - `customer.subscription.created`
   - `customer.subscription.updated`
   - `customer.subscription.deleted`
   - `invoice.payment_succeeded`
   - `invoice.payment_failed`
5. Copy the **Signing secret** (starts with `whsec_`)
6. Update `.kamal/secrets` with the signing secret
7. Redeploy: `kamal env push` (updates environment variables only)

### Step 10: Verify Deployment

Visit your app and test these critical flows:

- ✅ **Sign up** with email + password
- ✅ **Create a project** (triggers keyword research job)
- ✅ **Wait for keyword research** to complete (~42 seconds)
- ✅ **Generate an article** from a keyword
- ✅ **Check Stripe billing** (test with test credit card)
- ✅ **Check email verification** (should receive email via Resend)

```bash
# Monitor logs in real-time
kamal app logs -f

# Check app status
kamal app details

# SSH into the server (if needed)
kamal app exec -i bash
```

---

## 🔄 Updating Your App (Redeployment)

After making code changes:

```bash
# Deploy updates (builds new image, rolls out to servers)
kamal deploy

# This does:
# 1. Build new Docker image
# 2. Push to registry
# 3. Pull on server
# 4. Zero-downtime swap (new container, then stop old)
# 5. Run migrations automatically
```

**Quick commands:**

```bash
# View logs
kamal app logs -f

# Restart app
kamal app restart

# Run Rails console
kamal app exec -i "bin/rails console"

# Run database console
kamal app exec -i "bin/rails dbconsole"

# Check app details (CPU, memory, uptime)
kamal app details

# Update environment variables only (no rebuild)
kamal env push
```

---

## 🐛 Troubleshooting

### Problem: "Docker build failed"

**Solution:** Make sure you have Docker Desktop running locally.

```bash
# Check Docker is running
docker ps

# If not, start Docker Desktop
open -a Docker
```

### Problem: "Cannot connect to database"

**Solution:** Verify `DATABASE_URL` is set correctly.

```bash
# Check environment variables on server
kamal app exec "printenv | grep DATABASE_URL"

# Test database connection
kamal app exec "bin/rails runner 'puts ActiveRecord::Base.connection.execute(\"SELECT 1\").to_a'"
```

### Problem: "Solid Queue jobs not processing"

**Solution:** Ensure `SOLID_QUEUE_IN_PUMA` is set to `true` in `config/deploy.yml`.

```bash
# Check if Solid Queue is running
kamal app logs | grep "SolidQueue"

# Should see: "SolidQueue supervisor started"
```

### Problem: "Out of memory / App crashed"

**Solution:** Upgrade server to 2GB RAM or add swap space.

```bash
# For Fly.io, scale memory
fly scale memory 2048 --app verysimpleseo

# For other VPS, add swap
kamal app exec -i bash
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

### Problem: "SSL certificate error"

**Solution:** If using custom domain, ensure DNS is pointed correctly.

```bash
# For Fly.io
fly certs show verysimpleseo.com

# For other servers, check Traefik logs (Kamal uses Traefik for SSL)
kamal traefik logs
```

---

## 📊 Monitoring & Performance

### View Real-time Logs

```bash
# All logs
kamal app logs -f

# Filter for errors
kamal app logs | grep ERROR

# Filter for jobs
kamal app logs | grep "KeywordResearchJob\|ArticleGenerationJob"
```

### Check Resource Usage

```bash
# App container stats
kamal app details

# PostgreSQL stats (if on Fly.io)
fly postgres connect -a verysimpleseo-db
\l  # List databases
\dt # List tables
SELECT count(*) FROM users;
\q
```

### Performance Optimization

Once deployed, monitor these:

1. **Database indexes** - Already added in migrations ✅
2. **Solid Queue workers** - Increase `JOB_CONCURRENCY` if jobs are slow
3. **Puma threads** - Default is good for 1-2GB RAM servers
4. **Asset caching** - Thruster handles this automatically ✅

---

## 💰 Cost Estimates

### Fly.io (Recommended for MVP)

- **App VM** (shared-cpu-1x, 1GB RAM): $5/month
- **PostgreSQL** (shared-cpu-1x, 1GB RAM): $5/month
- **Total:** ~$10/month

**Scaling:**
- 2GB RAM app: $12/month (recommended after 10+ users)
- 2GB PostgreSQL: $12/month (recommended after 50+ users)

### Alternative: Hetzner (Europe)

- **CX11 VPS** (1 vCPU, 2GB RAM, 20GB SSD): €4.5/month (~$5)
- **Managed PostgreSQL**: €8/month or self-hosted on same VPS

**Total:** €4.5-12.50/month ($5-13)

### Alternative: DigitalOcean

- **Basic Droplet** (1GB RAM): $6/month
- **Managed PostgreSQL** (1GB): $15/month
- **Total:** $21/month

---

## 🔐 Security Checklist

Before going live:

- ✅ Use production API keys (not test keys)
- ✅ Enable Stripe webhook signature verification
- ✅ Set `RAILS_ENV=production`
- ✅ Never commit `config/master.key` to git (already in .gitignore)
- ✅ Never commit `.kamal/secrets` to git (already in .gitignore)
- ✅ Use HTTPS (enforced by Kamal/Traefik automatically)
- ✅ Set strong database password (Fly.io generates this automatically)
- ✅ Rotate secrets regularly (every 90 days)

---

## 🎉 Next Steps After Deployment

1. **Set up monitoring** - Use Fly.io metrics or add Honeybadger/Sentry
2. **Configure backups** - Fly.io PostgreSQL has automatic daily backups
3. **Add custom domain** - See [Custom Domain Setup](#custom-domain-setup)
4. **Beta user outreach** - Start Phase 10 of the roadmap
5. **Monitor job failures** - Check logs daily for first week

---

## 🌐 Custom Domain Setup

### For Fly.io

```bash
# Add custom domain
fly certs add verysimpleseo.com -a verysimpleseo

# Get DNS instructions
fly certs show verysimpleseo.com -a verysimpleseo

# Update DNS (at your domain registrar):
# Add A record: @ -> [Fly IPv4]
# Add AAAA record: @ -> [Fly IPv6]

# Update deploy.yml
proxy:
  ssl: true
  host: verysimpleseo.com

# Redeploy
kamal deploy
```

### For Other Providers

Use Cloudflare (free SSL):
1. Add site to Cloudflare
2. Update nameservers at registrar
3. Add A record pointing to your server IP
4. SSL mode: "Full (strict)"

---

## 📚 Additional Resources

- **Kamal Docs:** https://kamal-deploy.org
- **Fly.io Docs:** https://fly.io/docs
- **Rails 8 Deployment:** https://guides.rubyonrails.org/deploying_rails_applications.html
- **Solid Queue:** https://github.com/rails/solid_queue
- **Solid Cable:** https://github.com/rails/solid_cable

---

## ✅ Deployment Complete!

Your VerySimpleSEO app should now be live at `https://verysimpleseo.fly.dev` (or your custom domain).

**Test the full user flow:**
1. Sign up → Create project → Research keywords → Generate article → Upgrade plan

**Monitor for first 48 hours:**
- Check logs for errors
- Verify background jobs complete
- Test Stripe payments
- Ensure emails send

**Ship it and get feedback!** 🚀
