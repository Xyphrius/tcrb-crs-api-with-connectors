# Makefile — one-command E2E
SHELL := /bin/bash
DB_SVC := db
API_PORT := 8080

.PHONY: up down reset-db logs-db psql smoke ingest normalize score health product test e2e clean build-docker run-docker stop-docker logs-docker health-docker docker-prod setup-prod-secrets verify-prod

up:
	docker compose up -d db redis

down:
	docker compose down

reset-db:
	# DANGER: wipes data volume then re-runs init SQL
	docker compose down -v
	docker compose up -d db
	@echo "Waiting for Postgres..."
	@docker compose exec -T db bash -lc 'until pg_isready -U postgres -d tcrb; do sleep 1; done'
	@docker compose exec -T db psql -U postgres -d tcrb -c "\dt" || true

logs-db:
	docker compose logs -f db

psql:
	docker compose exec -it db psql -U postgres -d tcrb

smoke:
	# list tables
	docker compose exec -T db psql -U postgres -d tcrb -c "\dt"
	# sample query
	docker compose exec -T db psql -U postgres -d tcrb -c \
	 "SELECT p.id, p.name, s.crs, s.confidence FROM products p LEFT JOIN scores s ON s.product_id=p.id ORDER BY s.computed_at DESC NULLS LAST LIMIT 5;"
	# API checks (requires server running)
	@echo "Health:" && curl -s http://localhost:$(API_PORT)/health || true

# Docker production commands
IMAGE ?= tcrb-crs-api:prod

build-docker:
	docker build -t $(IMAGE) .

run-docker:
	docker rm -f tcrb-crs-api 2>/dev/null || true
	docker run -d --name tcrb-crs-api \
		-p 8080:8080 \
		--env-file .env \
		$(IMAGE)

stop-docker:
	docker rm -f tcrb-crs-api 2>/dev/null || true

logs-docker:
	docker logs -f tcrb-crs-api

health-docker:
	curl -s http://localhost:8080/health && echo
	curl -s http://localhost:8080/metrics && echo

health:
	@echo "🔎 Health check:"
	@curl -s http://localhost:$(API_PORT)/health | jq .

ingest:
	@echo "▶️  Ingesting sources into staging_sources..."
	npm run ingest || true
	@docker compose exec -T $(DB_SVC) psql -U postgres -d tcrb -c "select source, count(*) from staging_sources group by 1 order by 1;"

normalize:
	@echo "▶️  Normalizing dutchie → brands/products/listings..."
	node src/jobs/normalize-dutchie.js
	@docker compose exec -T $(DB_SVC) psql -U postgres -d tcrb -c "select count(*) as products from products;"

score:
	@echo "▶️  Computing scores..."
	node src/jobs/compute-scores.js
	@docker compose exec -T $(DB_SVC) psql -U postgres -d tcrb -c "select count(*) as scores from scores;"

product:
	@docker compose exec -T $(DB_SVC) psql -U postgres -d tcrb -c "select id,name from products limit 1;" | awk 'NR==3{print $$1}'

test:
	@PID=$$( $(MAKE) -s product ); \
	if [ -z "$$PID" ]; then echo "No product id found. Run 'make ingest normalize score' first."; exit 1; fi; \
	echo "🔎 Testing product: $$PID"; \
	curl -s "http://localhost:$(API_PORT)/v1/products/$$PID/score" | jq .

e2e:
	@$(MAKE) up
	@$(MAKE) ingest
	@$(MAKE) normalize
	@$(MAKE) score
	@$(MAKE) test

clean:
	@echo "🧹 Stopping containers (keeping volumes)..."
	docker compose down

# Production credential management
setup-prod-secrets:
	@echo "🔐 Setting up production secrets..."
	@if [ ! -f .env.prod ]; then \
		echo "❌ .env.prod not found. Copy env.prod.template to .env.prod and fill in your values:"; \
		echo "   cp env.prod.template .env.prod"; \
		echo "   # Edit .env.prod with your real production credentials"; \
		exit 1; \
	fi
	@echo "✅ .env.prod found"
	@echo "📋 Available production commands:"
	@echo "   make docker-prod     # Run production container locally"
	@echo "   make verify-prod     # Test production connections"

# Full production setup with guided workflow
setup-prod:
	@echo "🚀 Running full production setup workflow..."
	@./scripts/setup-production.sh

# Helper to get production credentials from providers
get-prod-creds:
	@echo "🔐 Getting production credentials from providers..."
	@./scripts/get-production-credentials.sh

# CI/CD production secrets management
prod-secrets:
	@./scripts/ci-secrets.sh

prod-deploy:
	@echo "Triggering deploy via CI (push)…"
	git add -A && git commit -m "ci: deploy" || true
	git push origin HEAD

# Production container with real credentials
docker-prod: setup-prod-secrets
	@echo "🚀 Starting production container with real credentials..."
	docker compose -f docker-compose.prod.yml up -d
	@echo "⏳ Waiting for container to be ready..."
	@sleep 5
	@echo "🔍 Health check:"
	@curl -s http://localhost:8080/health && echo
	@echo "📊 Metrics:"
	@curl -s http://localhost:8080/metrics && echo

# Verify production connections work
verify-prod:
	@echo "🔍 Verifying production connections..."
	@echo "Health endpoint:"
	@curl -s http://localhost:8080/health | jq . || echo "❌ Health check failed"
	@echo "Metrics endpoint:"
	@curl -s http://localhost:8080/metrics | jq . || echo "❌ Metrics failed"
	@echo "📊 Database connection test (if /v1/products exists):"
	@curl -s "http://localhost:8080/v1/products" | jq . 2>/dev/null || echo "ℹ️  /v1/products endpoint not available yet"
