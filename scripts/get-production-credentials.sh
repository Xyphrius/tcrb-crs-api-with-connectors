#!/bin/bash
# Production Credentials Helper Script
# Guides you through getting real production credentials

set -e

echo "🔐 TCRB CRS API - Production Credentials Helper"
echo "================================================"
echo ""

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}📋 This script will help you get real production credentials${NC}"
echo -e "${BLUE}   from various providers. Follow the steps below:${NC}"
echo ""

# Check if .env.prod exists
if [ -f .env.prod ]; then
    echo -e "${GREEN}✅ .env.prod found${NC}"
else
    echo -e "${YELLOW}⚠️  .env.prod not found - creating from template${NC}"
    cp env.prod.template .env.prod
    echo -e "${GREEN}✅ .env.prod created from template${NC}"
fi

echo ""
echo -e "${BLUE}🌐 Step 1: PostgreSQL Database${NC}"
echo "=================================="
echo -e "${YELLOW}Recommended: Neon (Free Tier)${NC}"
echo "1. Go to: https://neon.tech"
echo "2. Sign up and create a new project"
echo "3. Go to 'Connection Details' tab"
echo "4. Copy these values:"
echo "   - PGHOST (hostname)"
echo "   - PGUSER (username)"
echo "   - PGPASSWORD (password)"
echo "   - PGDATABASE (database name)"
echo "5. Set PGSSLMODE=require (Neon requires TLS)"
echo ""

echo -e "${BLUE}🌐 Step 2: Redis Database${NC}"
echo "================================"
echo -e "${YELLOW}Recommended: Upstash (Free Tier)${NC}"
echo "1. Go to: https://upstash.com"
echo "2. Sign up and go to Redis → Create Database"
echo "3. Choose a region close to you"
echo "4. Copy the REDIS_URL (full connection string)"
echo ""

echo -e "${BLUE}🌐 Step 3: Sentry Error Tracking${NC}"
echo "======================================="
echo -e "${YELLOW}Recommended: Sentry (Free Tier)${NC}"
echo "1. Go to: https://sentry.io"
echo "2. Sign up and create a new project"
echo "3. Choose 'Node.js' as platform"
echo "4. Go to Settings → Projects → Client Keys (DSN)"
echo "5. Copy the SENTRY_DSN"
echo ""

echo -e "${BLUE}🌐 Step 4: Notion Integration${NC}"
echo "=================================="
echo -e "${GREEN}✅ You already have this configured!${NC}"
echo "Your current values:"
echo "   - NOTION_TOKEN: $(grep NOTION_TOKEN .env.prod | cut -d'=' -f2)"
echo "   - NOTION_CRS_DATABASE_ID: $(grep NOTION_CRS_DATABASE_ID .env.prod | cut -d'=' -f2)"
echo ""

echo -e "${BLUE}📝 Step 5: Update .env.prod${NC}"
echo "================================"
echo "1. Edit .env.prod with your real credentials:"
echo "   nano .env.prod"
echo ""
echo "2. Replace all <your-*> placeholders with real values"
echo ""
echo "3. Save and exit"
echo ""

echo -e "${BLUE}🧪 Step 6: Test Production Setup${NC}"
echo "======================================"
echo "Once you've updated .env.prod, run:"
echo "   make setup-prod"
echo "   make docker-prod"
echo "   make verify-prod"
echo ""

echo -e "${BLUE}🚀 Step 7: Deploy to Production${NC}"
echo "====================================="
echo "After testing locally:"
echo "1. Set GitHub Actions secrets (if using CI/CD)"
echo "2. Set Kubernetes secrets (if deploying to K8s)"
echo "3. Push to main or create a tag to trigger deployment"
echo ""

echo -e "${GREEN}🎯 Ready to get started?${NC}"
echo "Open the URLs above in your browser and follow the steps."
echo "Come back here when you have your credentials ready!"
echo ""
echo -e "${BLUE}💡 Tip: You can run this script again anytime with:${NC}"
echo "   ./scripts/get-production-credentials.sh"

