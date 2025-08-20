
## 2025-08-19T23:23:48Z – Ops finalize
- INTERNAL_KEY rotated (store in your password manager).
- Warm machine: `./scripts/fly-warm.sh`
- Cool down: `./scripts/fly-cool.sh`
- Rollback (Fly): `flyctl -a tcrb-crs-api releases list` then `flyctl -a tcrb-crs-api deploy --image <previous>`
- Smoke:
  ```bash
  curl -s https://api.policyandplant.com/health
  curl -i https://api.policyandplant.com/metrics | head -5            # expect 403
  curl -s https://api.policyandplant.com/v1/products | jq . | head -40
  ```

### Safe metrics smoke (no secrets in repo)
# Set the INTERNAL_KEY from your password manager before running:
# export INTERNAL_KEY=***redacted***
curl -s https://api.policyandplant.com/health
curl -i -s https://api.policyandplant.com/metrics | head -5      # expect 403
curl -s -H "X-Internal-Key: $INTERNAL_KEY" https://api.policyandplant.com/metrics | head -10
curl -s https://api.policyandplant.com/v1/products | jq . | head -40
