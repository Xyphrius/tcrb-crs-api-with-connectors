#!/bin/bash
# Production Credentials Setup Script
# Implements the Cursor Operator Runbook for TCRB CRS API

set -e

echo "🛠️  TCRB CRS API - Production Credentials Setup"
echo "=================================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check prerequisites
check_prereqs() {
    echo -e "${BLUE}🔍 Checking prerequisites...${NC}"
    
    # Check if .env.prod exists
    if [ -f .env.prod ]; then
        echo -e "${GREEN}✅ .env.prod found${NC}"
    else
        echo -e "${YELLOW}⚠️  .env.prod not found - will create template${NC}"
    fi
    
    # Check Docker
    if command -v docker &> /dev/null; then
        echo -e "${GREEN}✅ Docker found${NC}"
    else
        echo -e "${RED}❌ Docker not found. Please install Docker first.${NC}"
        exit 1
    fi
    
    # Check kubectl if K8s deployment is needed
    if command -v kubectl &> /dev/null; then
        echo -e "${GREEN}✅ kubectl found${NC}"
        KUBECTL_AVAILABLE=true
    else
        echo -e "${YELLOW}⚠️  kubectl not found - K8s commands will be skipped${NC}"
        KUBECTL_AVAILABLE=false
    fi
    
    # Check GitHub CLI
    if command -v gh &> /dev/null; then
        echo -e "${GREEN}✅ GitHub CLI found${NC}"
        GH_AVAILABLE=true
    else
        echo -e "${YELLOW}⚠️  GitHub CLI not found - GitHub Actions setup will be skipped${NC}"
        echo -e "${YELLOW}   Install with: brew install gh${NC}"
        GH_AVAILABLE=false
    fi
}

# Create .env.prod from template
create_env_prod() {
    if [ ! -f .env.prod ]; then
        echo -e "${BLUE}📝 Creating .env.prod from template...${NC}"
        if [ -f env.prod.template ]; then
            cp env.prod.template .env.prod
            echo -e "${GREEN}✅ .env.prod created from template${NC}"
            echo -e "${YELLOW}⚠️  IMPORTANT: Edit .env.prod with your real production credentials${NC}"
            echo -e "${YELLOW}   Then run this script again to continue setup${NC}"
            exit 0
        else
            echo -e "${RED}❌ env.prod.template not found${NC}"
            exit 1
        fi
    fi
}

# Validate .env.prod has real values
validate_env_prod() {
    echo -e "${BLUE}🔍 Validating .env.prod configuration...${NC}"
    
    # Check for placeholder values
    if grep -q "<your-" .env.prod; then
        echo -e "${RED}❌ .env.prod still contains placeholder values${NC}"
        echo -e "${YELLOW}Please edit .env.prod and replace all <your-*> values with real credentials${NC}"
        echo -e "${YELLOW}Then run this script again${NC}"
        exit 1
    fi
    
    # Check required variables
    required_vars=("PGHOST" "PGUSER" "PGPASSWORD" "PGDATABASE" "REDIS_URL" "NOTION_TOKEN" "NOTION_CRS_DATABASE_ID")
    
    for var in "${required_vars[@]}"; do
        if ! grep -q "^${var}=" .env.prod; then
            echo -e "${RED}❌ Missing required variable: ${var}${NC}"
            exit 1
        fi
    done
    
    echo -e "${GREEN}✅ .env.prod validation passed${NC}"
}

# Test local production container
test_local_prod() {
    echo -e "${BLUE}🧪 Testing local production container...${NC}"
    
    # Stop any existing container
    docker compose -f docker-compose.prod.yml down 2>/dev/null || true
    
    # Start production container
    echo -e "${BLUE}🚀 Starting production container...${NC}"
    docker compose -f docker-compose.prod.yml up -d
    
    # Wait for container to be ready
    echo -e "${BLUE}⏳ Waiting for container to be ready...${NC}"
    sleep 10
    
    # Health check
    echo -e "${BLUE}🔍 Health check...${NC}"
    if curl -s http://localhost:8080/health > /dev/null; then
        echo -e "${GREEN}✅ Health endpoint responding${NC}"
    else
        echo -e "${RED}❌ Health endpoint failed${NC}"
        docker compose -f docker-compose.prod.yml logs api
        exit 1
    fi
    
    # Metrics check
    echo -e "${BLUE}📊 Metrics check...${NC}"
    if curl -s http://localhost:8080/metrics > /dev/null; then
        echo -e "${GREEN}✅ Metrics endpoint responding${NC}"
    else
        echo -e "${RED}❌ Metrics endpoint failed${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Local production container test passed${NC}"
}

# Setup GitHub Actions secrets
setup_github_actions() {
    if [ "$GH_AVAILABLE" = false ]; then
        echo -e "${YELLOW}⚠️  Skipping GitHub Actions setup (gh CLI not available)${NC}"
        return
    fi
    
    echo -e "${BLUE}🔐 Setting up GitHub Actions secrets...${NC}"
    
    # Check if we're in a git repo
    if [ ! -d .git ]; then
        echo -e "${YELLOW}⚠️  Not in a git repository - skipping GitHub Actions setup${NC}"
        return
    fi
    
    # Check if gh is authenticated
    if ! gh auth status &> /dev/null; then
        echo -e "${YELLOW}⚠️  GitHub CLI not authenticated - run 'gh auth login' first${NC}"
        return
    fi
    
    echo -e "${BLUE}📋 Available commands to set GitHub Actions secrets:${NC}"
    echo -e "${YELLOW}# Database${NC}"
    echo -e "gh secret set PGHOST --body \"$(grep PGHOST .env.prod | cut -d'=' -f2)\""
    echo -e "gh secret set PGPORT --body \"$(grep PGPORT .env.prod | cut -d'=' -f2)\""
    echo -e "gh secret set PGUSER --body \"$(grep PGUSER .env.prod | cut -d'=' -f2)\""
    echo -e "gh secret set PGPASSWORD --body \"$(grep PGPASSWORD .env.prod | cut -d'=' -f2)\""
    echo -e "gh secret set PGDATABASE --body \"$(grep PGDATABASE .env.prod | cut -d'=' -f2)\""
    echo -e ""
    echo -e "${YELLOW}# Redis${NC}"
    echo -e "gh secret set REDIS_URL --body \"$(grep REDIS_URL .env.prod | cut -d'=' -f2)\""
    echo -e ""
    echo -e "${YELLOW}# Sentry${NC}"
    if grep -q SENTRY_DSN .env.prod; then
        echo -e "gh secret set SENTRY_DSN --body \"$(grep SENTRY_DSN .env.prod | cut -d'=' -f2)\""
    fi
    echo -e ""
    echo -e "${YELLOW}# Notion${NC}"
    echo -e "gh secret set NOTION_TOKEN --body \"$(grep NOTION_TOKEN .env.prod | cut -d'=' -f2)\""
    echo -e "gh secret set NOTION_CRS_DATABASE_ID --body \"$(grep NOTION_CRS_DATABASE_ID .env.prod | cut -d'=' -f2)\""
    echo -e ""
    echo -e "${BLUE}💡 Run these commands to set your secrets, then push to trigger CI/CD${NC}"
}

# Setup Kubernetes secrets
setup_k8s_secrets() {
    if [ "$KUBECTL_AVAILABLE" = false ]; then
        echo -e "${YELLOW}⚠️  Skipping Kubernetes setup (kubectl not available)${NC}"
        return
    fi
    
    echo -e "${BLUE}☸️  Setting up Kubernetes secrets...${NC}"
    
    # Check if we can connect to a cluster
    if ! kubectl cluster-info &> /dev/null; then
        echo -e "${YELLOW}⚠️  Cannot connect to Kubernetes cluster - skipping K8s setup${NC}"
        return
    fi
    
    echo -e "${BLUE}📋 Available commands to set Kubernetes secrets:${NC}"
    echo -e "${YELLOW}# Create/update the secret${NC}"
    echo -e "kubectl delete secret tcrb-crs-secrets 2>/dev/null || true"
    echo -e "kubectl create secret generic tcrb-crs-secrets \\"
    echo -e "  --from-literal=PGHOST=\"$(grep PGHOST .env.prod | cut -d'=' -f2)\" \\"
    echo -e "  --from-literal=PGPORT=\"$(grep PGPORT .env.prod | cut -d'=' -f2)\" \\"
    echo -e "  --from-literal=PGUSER=\"$(grep PGUSER .env.prod | cut -d'=' -f2)\" \\"
    echo -e "  --from-literal=PGPASSWORD=\"$(grep PGPASSWORD .env.prod | cut -d'=' -f2)\" \\"
    echo -e "  --from-literal=PGDATABASE=\"$(grep PGDATABASE .env.prod | cut -d'=' -f2)\" \\"
    echo -e "  --from-literal=REDIS_URL=\"$(grep REDIS_URL .env.prod | cut -d'=' -f2)\" \\"
    
    if grep -q SENTRY_DSN .env.prod; then
        echo -e "  --from-literal=SENTRY_DSN=\"$(grep SENTRY_DSN .env.prod | cut -d'=' -f2)\" \\"
    fi
    
    echo -e "  --from-literal=NOTION_TOKEN=\"$(grep NOTION_TOKEN .env.prod | cut -d'=' -f2)\" \\"
    echo -e "  --from-literal=NOTION_CRS_DATABASE_ID=\"$(grep NOTION_CRS_DATABASE_ID .env.prod | cut -d'=' -f2)\""
    echo -e ""
    echo -e "${BLUE}💡 Run these commands to set your K8s secrets${NC}"
}

# Main execution
main() {
    check_prereqs
    create_env_prod
    validate_env_prod
    test_local_prod
    setup_github_actions
    setup_k8s_secrets
    
    echo -e "${GREEN}🎉 Production setup complete!${NC}"
    echo -e "${BLUE}📋 Next steps:${NC}"
    echo -e "   1. Set GitHub Actions secrets (if using CI/CD)"
    echo -e "   2. Set Kubernetes secrets (if deploying to K8s)"
    echo -e "   3. Push to main or create a tag to trigger deployment"
    echo -e ""
    echo -e "${BLUE}🚀 Available commands:${NC}"
    echo -e "   make docker-prod     # Run production container locally"
    echo -e "   make verify-prod     # Test production connections"
    echo -e "   make e2e            # Full E2E test with local DB"
}

# Run main function
main "$@"

