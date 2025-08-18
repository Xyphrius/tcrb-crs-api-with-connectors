# TCRB CRS API

A production-ready Node.js API for TCRB CRS (Cannabis Retail Score) calculations with automated CI/CD, Kubernetes deployment, and Notion integration.

## 🚀 Features

- **Express.js API** with structured logging and request tracing
- **PostgreSQL database** with auto-initialization and sample data
- **Redis** for caching and session management
- **Sentry integration** for error tracking and monitoring
- **Request ID middleware** for distributed tracing
- **Health checks** and metrics endpoints (`/health`, `/metrics`, `/metrics/prom`)
- **Docker** multi-stage builds with health checks
- **Kubernetes** manifests with liveness/readiness probes
- **GitHub Actions** CI/CD pipeline
- **Notion sync** for score data
- **Cursor IDE** integration with one-click flows

## 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Frontend      │    │   Load Balancer │    │   Kubernetes    │
│   (React/Vue)   │───▶│   (NGINX/ALB)   │───▶│   Cluster       │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                                        │
                                                        ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Notion        │◀───│   TCRB CRS API  │───▶│   PostgreSQL    │
│   Database      │    │   (Node.js)     │    │   Database      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                │
                                ▼
                       ┌─────────────────┐
                       │   Redis Cache   │
                       └─────────────────┘
```

## 🛠️ Quick Start

### Prerequisites

- Node.js 20+
- Docker & Docker Compose
- PostgreSQL (or use Docker)
- Redis (or use Docker)

### Development Setup

1. **Clone and install dependencies:**
   ```bash
   git clone <your-repo>
   cd tcrb-crs-api-with-connectors
   npm install
   ```

2. **Environment configuration:**
   ```bash
   cp .env.example .env
   # Edit .env with your database credentials
   ```

3. **Start development stack:**
   ```bash
   # In Cursor: Run flow: bootstrap-db
   # Or manually:
   make up
   make smoke
   npm run dev
   ```

4. **Verify endpoints:**
   ```bash
   curl http://localhost:8080/health
   curl http://localhost:8080/metrics
   ```

### Cursor IDE Integration

This project includes `.cursorrules` for one-click development flows:

- **`bootstrap-db`** - Fresh database setup with sample data
- **`api-dev`** - Start API and verify health
- **`smoke`** - Quick verification tests
- **`scores->notion`** - Compute scores and sync to Notion
- **`docker-prod`** - Production compose deployment

## 🐳 Docker

### Development
```bash
make up          # Start PostgreSQL + Redis
make reset-db    # Reset database with fresh data
make smoke       # Run smoke tests
```

### Production
```bash
# Build production image
make build-docker

# Run production container
make run-docker

# Check health
make health-docker
```

### Production Compose
```bash
# Start production stack
docker compose -f docker-compose.prod.yml up -d

# Check status
docker compose -f docker-compose.prod.yml ps
```

## ☸️ Kubernetes Deployment

### Prerequisites
- Kubernetes cluster access
- `kubectl` configured
- GitHub repository with Actions enabled

### Deploy

1. **Apply secrets first:**
   ```bash
   kubectl apply -f k8s/secret.yaml
   ```

2. **Deploy application:**
   ```bash
   kubectl apply -f k8s/service.yaml
   kubectl apply -f k8s/deployment.yaml
   ```

3. **Verify deployment:**
   ```bash
   kubectl get pods -l app=tcrb-crs-api
   kubectl rollout status deployment/tcrb-crs-api
   ```

4. **Access the service:**
   ```bash
   kubectl port-forward svc/tcrb-crs-api 8080:80
   curl http://localhost:8080/health
   ```

## 🔄 CI/CD Pipeline

### GitHub Actions Setup

1. **Enable Actions permissions:**
   - Go to Settings → Actions → General
   - Set "Workflow permissions" to "Read and write permissions"

2. **Add Kubernetes secret:**
   ```bash
   base64 -w0 ~/.kube/config
   # Add as KUBE_CONFIG_B64 in repo secrets
   ```

3. **Push to trigger deployment:**
   ```bash
   git add -A
   git commit -m "feat: add CI/CD pipeline"
   git push origin main
   ```

### Pipeline Features

- **Automated builds** on push to main
- **Docker image** pushed to GitHub Container Registry
- **Kubernetes deployment** with zero-downtime rollout
- **Multi-platform** support (linux/amd64)
- **Layer caching** for faster builds

## 📊 Monitoring & Observability

### Health Endpoints

- **`/health`** - Basic health check (fast, no DB)
- **`/metrics`** - System metrics in JSON format
- **`/metrics/prom`** - Prometheus-compatible metrics

### Logging

- **Structured logging** with Pino
- **Request ID tracing** for distributed debugging
- **HTTP request logging** with timing

### Error Tracking

- **Sentry integration** for error monitoring
- **Request context** preserved in error reports
- **Performance profiling** available

## 🔐 Security

- **Helmet** security headers
- **Rate limiting** (100 requests/minute)
- **CORS** configuration
- **Non-root** Docker containers
- **Environment-based** configuration

## 🗄️ Database Schema

### Tables

- **`brands`** - Product brand information
- **`products`** - Product catalog with categories
- **`scores`** - CRS scores with confidence and metadata

### Sample Data

The database automatically initializes with sample data:
- Extract Masters brand
- Demo OG 1g product
- Sample CRS score (87.50 with 92% confidence)

## 🚀 Production Checklist

- [ ] Environment variables configured
- [ ] Database credentials secured
- [ ] Sentry DSN configured
- [ ] Notion integration tokens set
- [ ] Kubernetes secrets applied
- [ ] Health checks passing
- [ ] Metrics endpoints responding
- [ ] CI/CD pipeline working
- [ ] Monitoring alerts configured

## 📝 API Endpoints

### Health & Monitoring
- `GET /health` - Health check
- `GET /metrics` - System metrics (JSON)
- `GET /metrics/prom` - Prometheus metrics

### Products
- `GET /v1/products` - List all products with scores
- `GET /v1/products/:id/score` - Get specific product score

### Response Format
```json
{
  "product_id": "uuid",
  "product_name": "Demo OG 1g",
  "brand_name": "Extract Masters",
  "crs_score": 87.50,
  "confidence": 0.92,
  "reason_codes": ["GOOD_COVERAGE", "FAIR_PRICE"],
  "feature_vector": {"listing_count": 3, "avg_price_cents": 2999},
  "version": "1.0",
  "scored_at": "2025-08-18T04:46:34.049Z"
}
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## 📄 License

[Your License Here]

## 🆘 Support

For issues and questions:
- Check the [Issues](../../issues) page
- Review the health endpoints
- Check Sentry for error details
- Verify Kubernetes pod status

---

**Built with ❤️ using modern DevOps practices**
