#!/usr/bin/env bash
set -euo pipefail

# --- Config ---
ENV_FILE=".env.prod"
SECRET_NAME="tcrb-crs-secrets"     # k8s secret name

# --- Checks ---
command -v gh >/dev/null 2>&1 || { echo "❌ GitHub CLI (gh) is required"; exit 1; }
command -v kubectl >/dev/null 2>&1 || echo "⚠️ kubectl not found (K8s step will be skipped)"
[[ -f "$ENV_FILE" ]] || { echo "❌ $ENV_FILE not found"; exit 1; }

REPO=$(git remote get-url origin | sed -E 's#.*/([^/]+/[^/\.]+)(\.git)?#\1#')
[[ -n "$REPO" ]] || { echo "❌ Could not infer repo (set origin)"; exit 1; }
echo "📝 Using repo: $REPO"

# --- Load vars from .env.prod ---
echo "🔍 Validating keys in $ENV_FILE…"

# Check required keys
NEEDED_KEYS=("PGHOST" "PGPORT" "PGUSER" "PGPASSWORD" "PGDATABASE" "REDIS_URL" "SENTRY_DSN" "NOTION_TOKEN" "NOTION_CRS_DATABASE_ID")

MISSING=0
for k in "${NEEDED_KEYS[@]}"; do
  if grep -q "^${k}=" "$ENV_FILE"; then
    echo "   ✅ $k present"
  else
    echo "   ❌ $k is missing"
    MISSING=1
  fi
done

[[ $MISSING -eq 0 ]] || { echo "❌ Fill missing values in $ENV_FILE"; exit 1; }

echo "⬆️  Pushing secrets to GitHub Actions…"
for k in "${NEEDED_KEYS[@]}"; do
  VALUE=$(grep "^${k}=" "$ENV_FILE" | cut -d'=' -f2-)
  gh secret set "$k" -R "$REPO" --body "$VALUE" >/dev/null
  echo "   • $k set"
done

if command -v kubectl >/dev/null 2>&1; then
  echo "🔐 Syncing secrets to Kubernetes: $SECRET_NAME"
  kubectl delete secret "$SECRET_NAME" --ignore-not-found >/dev/null 2>&1 || true
  
  # Build kubectl command
  KUBECTL_CMD="kubectl create secret generic $SECRET_NAME"
  for k in "${NEEDED_KEYS[@]}"; do
    VALUE=$(grep "^${k}=" "$ENV_FILE" | cut -d'=' -f2-)
    KUBECTL_CMD="$KUBECTL_CMD --from-literal=$k=\"$VALUE\""
  done
  
  eval "$KUBECTL_CMD"
  echo "   ✅ K8s secret updated"
else
  echo "⚠️ Skipping Kubernetes (kubectl not found)"
fi

echo "🚀 Creating CI/CD trigger commit…"
git add -A
git commit -m "chore(ci): update prod secrets & trigger pipeline" || true
git push origin HEAD

echo "✅ Done. CI/CD will run with real connections."
