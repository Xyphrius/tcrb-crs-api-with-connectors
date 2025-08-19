#!/usr/bin/env bash
set -euo pipefail

# --- Config (edit here if needed) ---
IMAGE="ghcr.io/xyphrius/tcrb-crs-api-with-connectors"
TAG="${TAG:-v$(date +%Y%m%d%H%M%S)}"       # override by: TAG=v1.0.3 ./scripts/deploy-smoke.sh
NAMESPACE="${NAMESPACE:-tcrb}"
DEPLOYMENT="${DEPLOYMENT:-tcrb-crs-api}"
SERVICE="${SERVICE:-tcrb-crs-api}"
K8S_DIR="${K8S_DIR:-k8s}"
PORT="${PORT:-8080}"
SMOKE_TIMEOUT="${SMOKE_TIMEOUT:-60}"

echo "🔧 Using:"
echo "  IMAGE:      $IMAGE"
echo "  TAG:        $TAG"
echo "  NAMESPACE:  $NAMESPACE"
echo "  DEPLOYMENT: $DEPLOYMENT"
echo "  SERVICE:    $SERVICE"
echo

# --- Preflight ---
command -v docker >/dev/null || { echo "❌ docker not found"; exit 1; }
command -v kubectl >/dev/null || { echo "❌ kubectl not found"; exit 1; }

echo "🔎 kubectl context: $(kubectl config current-context)"
if ! kubectl get ns "$NAMESPACE" >/dev/null 2>&1; then
  echo "🧪 Creating namespace $NAMESPACE"
  kubectl create namespace "$NAMESPACE"
fi

if ! kubectl -n "$NAMESPACE" get secret tcrb-crs-secrets >/dev/null 2>&1; then
  cat <<'MSG'
❌ Kubernetes secret "tcrb-crs-secrets" not found in the target namespace.

Create it first (example):
kubectl -n tcrb create secret generic tcrb-crs-secrets \
  --from-literal=PGHOST=<host> \
  --from-literal=PGPORT=5432 \
  --from-literal=PGUSER=<user> \
  --from-literal=PGPASSWORD=<password> \
  --from-literal=PGDATABASE=<db> \
  --from-literal=REDIS_URL=<redis-url> \
  --from-literal=SENTRY_DSN=<sentry-dsn> \
  --from-literal=NOTION_TOKEN=<notion-token> \
  --from-literal=NOTION_CRS_DATABASE_ID=<notion-db-id>

Re-run this script afterwards.
MSG
  exit 1
fi

# --- Build & Push ---
echo "🐳 Building $IMAGE:$TAG"
docker build -t "$IMAGE:$TAG" .

echo "📤 Pushing $IMAGE:$TAG to GHCR"
docker push "$IMAGE:$TAG"

# --- Apply Manifests (idempotent) ---
echo "📦 Applying k8s Service + Deployment (without image pin yet)"
kubectl -n "$NAMESPACE" apply -f "$K8S_DIR/service.yaml"
kubectl -n "$NAMESPACE" apply -f "$K8S_DIR/deployment.yaml"

# --- Set image + Rollout ---
echo "🚀 Setting image on deployment/$DEPLOYMENT"
kubectl -n "$NAMESPACE" set image deployment/"$DEPLOYMENT" api="$IMAGE:$TAG"

echo "⏳ Waiting for rollout to finish…"
kubectl -n "$NAMESPACE" rollout status deployment/"$DEPLOYMENT" --timeout=120s

# --- Smoke Test via port-forward ---
echo "🧪 Smoke test: /health and /metrics"
PF_PID=""
cleanup() { [[ -n "$PF_PID" ]] && kill "$PF_PID" >/dev/null 2>&1 || true; }
trap cleanup EXIT

kubectl -n "$NAMESPACE" port-forward svc/"$SERVICE" $PORT:80 >/dev/null 2>&1 &
PF_PID=$!

# wait a bit for port-forward
for i in $(seq 1 $SMOKE_TIMEOUT); do
  if curl -fsS "http://localhost:$PORT/health" >/dev/null 2>&1; break; fi
  sleep 1
done

echo "→ /health:"
curl -fsS "http://localhost:$PORT/health" || { echo "❌ /health failed"; exit 1; }
echo
echo "→ /metrics:"
curl -fsS "http://localhost:$PORT/metrics" || { echo "❌ /metrics failed"; exit 1; }
echo

echo "✅ Deploy + Smoke successful!"
echo "   Deployed: $IMAGE:$TAG"
echo "   Namespace: $NAMESPACE"
echo
echo "🔁 Roll back if needed:"
echo "   kubectl -n $NAMESPACE rollout undo deployment/$DEPLOYMENT"
