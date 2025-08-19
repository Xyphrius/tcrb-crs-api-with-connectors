# 🛠️ Production Credentials Setup Guide

This guide implements the **Cursor Operator Runbook** for generating production credentials and injecting them into your CI/CD pipeline.

## 🚀 Quick Start

```bash
# Run the automated production setup workflow
make setup-prod

# Or manually:
./scripts/setup-production.sh
```

## 📋 Prerequisites

### Required Tools
- **Docker** - for local production testing
- **GitHub CLI** (`gh`) - for setting Actions secrets
- **kubectl** - for Kubernetes deployment (optional)

### Install Missing Tools
```bash
# macOS
brew install gh
brew install kubectl

# Linux
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update && sudo apt install gh kubectl
```

## 🔐 Step 1: Provision Production Services

### A. PostgreSQL (Neon, AWS RDS, Supabase, etc.)

1. **Neon (Recommended)**
   - Go to [https://neon.tech](https://neon.tech) → Create project
   - Note connection details:
     - `PGHOST` (host)
     - `PGPORT` (usually 5432)
     - `PGUSER`
     - `PGPASSWORD`
     - `PGDATABASE`

2. **Alternative Providers**
   - **AWS RDS**: Console → RDS → Create database
   - **Supabase**: [https://supabase.com](https://supabase.com) → New project
   - **Render**: [https://render.com](https://render.com) → New PostgreSQL
   - **Railway**: [https://railway.app](https://railway.app) → New PostgreSQL
   - **DigitalOcean**: Console → Databases → Create cluster

### B. Redis (Upstash, AWS ElastiCache, etc.)

1. **Upstash (Recommended)**
   - Go to [https://upstash.com](https://upstash.com) → Redis → Create database
   - Copy `REDIS_URL` (full connection string)
   - Format: `rediss://default:<password>@<hostname>:<port>` (TLS) or `redis://...` (non-TLS)

2. **Alternative Providers**
   - **AWS ElastiCache**: Console → ElastiCache → Create cluster
   - **Redis Cloud**: [https://redis.com](https://redis.com) → Create subscription
   - **Azure Cache**: Portal → Redis Cache → Create

### C. Sentry (Error Tracking)

1. Go to [https://sentry.io](https://sentry.io) → Create Project (Platform: Node.js)
2. In Settings → Projects → Client Keys (DSN), copy `SENTRY_DSN`
3. Format: `https://<key>@oXXXX.ingest.sentry.io/YYYY`

### D. Notion (CRS Database Sync)

1. **Create Integration**
   - Go to [https://www.notion.so/my-integrations](https://www.notion.so/my-integrations)
   - Create new internal integration
   - Copy `NOTION_TOKEN` (starts with `secret_...`)

2. **Setup Database Access**
   - Open your CRS database in Notion
   - Copy the URL → extract `NOTION_CRS_DATABASE_ID` (long hex ID after last `/`)
   - Share the database with your integration (Settings → Connections → Add connections)

## 🔧 Step 2: Configure Local Environment

### Create Production Environment File

```bash
# Copy template
cp env.prod.template .env.prod

# Edit with real values
nano .env.prod  # or your preferred editor
```

**Example `.env.prod`:**
```bash
NODE_ENV=production
PORT=8080

# PostgreSQL (Neon)
PGHOST=ep-cool-name-123456.us-east-1.aws.neon.tech
PGPORT=5432
PGUSER=your_username
PGPASSWORD=your_password
PGDATABASE=neondb
PGSSLMODE=require

# Redis (Upstash)
REDIS_URL=rediss://default:password@hostname:port

# Sentry
SENTRY_DSN=https://key@o123456.ingest.sentry.io/789

# Notion
NOTION_TOKEN=secret_your_token_here
NOTION_CRS_DATABASE_ID=12345678-90ab-cdef-1234-567890abcdef
```

## 🧪 Step 3: Test Local Production

```bash
# Test production container with real credentials
make docker-prod

# Verify connections
make verify-prod

# Check logs if issues
docker compose -f docker-compose.prod.yml logs -f api
```

## 🚀 Step 4: Deploy to Production

### Option A: GitHub Actions (CI/CD)

```bash
# Authenticate GitHub CLI
gh auth login

# Set secrets (run these commands)
gh secret set PGHOST --body "your-pghost"
gh secret set PGPORT --body "5432"
gh secret set PGUSER --body "your-pguser"
gh secret set PGPASSWORD --body "your-pgpassword"
gh secret set PGDATABASE --body "your-pgdatabase"
gh secret set REDIS_URL --body "your-redis-url"
gh secret set SENTRY_DSN --body "your-sentry-dsn"
gh secret set NOTION_TOKEN --body "your-notion-token"
gh secret set NOTION_CRS_DATABASE_ID --body "your-notion-db-id"

# Trigger deployment
git commit --allow-empty -m "deploy: wire real secrets"
git push
# or create a tag:
git tag v1.0.1 && git push origin v1.0.1
```

### Option B: Kubernetes (Direct Deployment)

```bash
# Create/update secrets
kubectl delete secret tcrb-crs-secrets 2>/dev/null || true
kubectl create secret generic tcrb-crs-secrets \
  --from-literal=PGHOST="your-pghost" \
  --from-literal=PGPORT="5432" \
  --from-literal=PGUSER="your-pguser" \
  --from-literal=PGPASSWORD="your-pgpassword" \
  --from-literal=PGDATABASE="your-pgdatabase" \
  --from-literal=REDIS_URL="your-redis-url" \
  --from-literal=SENTRY_DSN="your-sentry-dsn" \
  --from-literal=NOTION_TOKEN="your-notion-token" \
  --from-literal=NOTION_CRS_DATABASE_ID="your-notion-db-id"

# Deploy
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/deployment.yaml
kubectl rollout status deployment/tcrb-crs-api --timeout=180s
```

## ✅ Step 5: Verify Production Deployment

### Health Checks

```bash
# Kubernetes
kubectl get pods -l app=tcrb-crs-api
kubectl port-forward svc/tcrb-crs-api 8080:80

# Health endpoints
curl -s http://localhost:8080/health | jq .
curl -s http://localhost:8080/metrics | jq .

# Test database connection
curl -s "http://localhost:8080/v1/products" | jq .
```

### Sentry Verification

1. Hit a route that might throw an error (temporary test)
2. Check Sentry dashboard for the event
3. Verify request ID tagging works

## 🆘 Troubleshooting

### Common Issues

#### Connection Refused (ECONNREFUSED)
```bash
# Check if services are running
docker compose -f docker-compose.prod.yml ps

# Check logs
docker compose -f docker-compose.prod.yml logs api

# Verify credentials in .env.prod
cat .env.prod
```

#### Database TLS Required
```bash
# Add to .env.prod
PGSSLMODE=require

# Restart container
make docker-prod
```

#### Pods CrashLoopBackOff (K8s)
```bash
# Check secrets exist
kubectl get secret tcrb-crs-secrets -o yaml

# Check pod logs
kubectl logs -l app=tcrb-crs-api

# Verify environment variables in deployment
kubectl get deployment tcrb-crs-api -o yaml
```

#### GitHub Actions Permission Denied
1. Go to Repo → Settings → Actions → General
2. Enable "Read and write permissions" under "Workflow permissions"
3. Re-run the workflow

### Probe Failures

```bash
# Increase probe delays in k8s/deployment.yaml
readinessProbe:
  initialDelaySeconds: 30  # Increase from 10
livenessProbe:
  initialDelaySeconds: 40  # Increase from 20
```

## 🔄 Available Commands

```bash
# Production setup
make setup-prod              # Full guided workflow
make setup-prod-secrets      # Check .env.prod exists
make docker-prod             # Run production container locally
make verify-prod             # Test production connections

# Development
make e2e                     # Full E2E test with local DB
make api-dev                 # Start dev server
make scores->notion          # Compute scores and sync to Notion

# Docker
make build-docker            # Build production image
make run-docker              # Run with .env
make stop-docker             # Stop container
make health-docker           # Health check
```

## 📚 Additional Resources

- [Cursor Rules](.cursorrules) - Project-specific development guidelines
- [Makefile](Makefile) - All available commands
- [Docker Compose](docker-compose.prod.yml) - Production container configuration
- [Kubernetes Manifests](k8s/) - Production deployment configuration

## 🎯 Next Steps

1. **Complete Setup**: Run `make setup-prod` and follow the prompts
2. **Test Locally**: Use `make docker-prod` to verify everything works
3. **Deploy**: Push to main or create a tag to trigger CI/CD
4. **Monitor**: Check GitHub Actions and Kubernetes deployment status
5. **Verify**: Use `make verify-prod` to confirm production connections

---

**Need Help?** Check the troubleshooting section above or run `make setup-prod` for guided assistance.

