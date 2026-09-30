#!/usr/bin/env bash
# Put the demo host back to the baseline release: no canary, stable = BASELINE_TAG, 100% traffic.
#   ./reset-site.sh 5.3.1-e972f71
set -euo pipefail
cd "$(dirname "$0")"
TAG="${1:?usage: reset-site.sh <baseline-image-tag>}"
./rollback.sh
sed -i "s/^SITE_STABLE_TAG=.*/SITE_STABLE_TAG=$TAG/" .env
docker compose pull -q site-stable
docker compose up -d --no-deps site-stable
source .env
for i in $(seq 1 30); do
  st=$(docker inspect -f '{{.State.Health.Status}}' "$(docker compose ps -q site-stable)")
  [ "$st" = healthy ] && break; sleep 2
done
./smoke.sh "https://$DOMAIN" "$TAG" stable
echo "✔ site reset: stable=$TAG, no canary"
