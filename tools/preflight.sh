#!/usr/bin/env bash
# Pre-demo checklist: is the estate, the site and GitHub in the clean baseline state?
# Usage: tools/preflight.sh [baseline-tag]   (needs gh auth; DOMAIN defaults to cognition.platformengineer.io)
set -uo pipefail
cd "$(dirname "$0")/.."

TAG="${1:-5.3.1-e972f71}"
DOMAIN="${DOMAIN:-cognition.platformengineer.io}"
ORG=$(python3 -c "import yaml;print(yaml.safe_load(open('repos.yaml'))['github_org'])")
REPOS=$(python3 -c "import yaml;print(' '.join('palmtree-'+r['name'] for r in yaml.safe_load(open('repos.yaml'))['repos']))")
fail=0
ok()   { echo "  ✔ $*"; }
bad()  { echo "  ✘ $*"; fail=1; }

echo "site"
stable=$(curl -sf "https://$DOMAIN/healthz" | python3 -c "import json,sys;d=json.load(sys.stdin);print(d['version'],d['color'])" 2>/dev/null || echo "unreachable")
[ "$stable" = "$TAG stable" ] && ok "stable = $TAG" || bad "stable is '$stable', expected '$TAG stable'  → make site-reset TAG=$TAG DEPLOY=..."
canary=$(curl -s -H 'X-Canary: 1' "https://$DOMAIN/healthz" | python3 -c "import json,sys;print(json.load(sys.stdin)['color'])" 2>/dev/null || echo "?")
[ "$canary" = "stable" ] && ok "no canary serving" || bad "canary container still serving ($canary)  → make site-reset"

echo "ops dashboard"
ops=$(curl -sf "https://$DOMAIN/ops/data.json" | python3 -c "import json,sys;d=json.load(sys.stdin);print(len(d['sessions']),d['after_available'])" 2>/dev/null || echo "unreachable")
[ "$ops" = "0 False" ] && ok "/ops/ at baseline (0 sessions, no after)" || bad "/ops/ shows '$ops' (sessions after_available)  → make reset && make dashboard && make ops-deploy DEPLOY=..."

echo "github"
for r in $REPOS; do
  prs=$(gh pr list -R "$ORG/$r" --state open --json headRefName --jq '[.[] | select(.headRefName|startswith("devin/"))] | length' 2>/dev/null || echo "?")
  [ "$prs" = "0" ] || bad "$r: $prs open devin/* PR(s)  → make reset"
  base=$(git -C "$r" rev-parse --short demo-baseline 2>/dev/null); head=$(git ls-remote -q "https://github.com/$ORG/$r" main | cut -c1-7)
  [ -n "$head" ] && [ "$head" = "$base" ] || bad "$r: origin/main $head != demo-baseline $base  → make reset"
done
pending=$(gh run list -R "$ORG/palmtree-owner-portal-bff" --workflow release -L 50 --json url,status --jq '.[] | select(.status=="waiting" or .status=="in_progress" or .status=="queued") | "\(.status) \(.url)"' 2>/dev/null)
if [ -z "$pending" ]; then ok "no release run pending/waiting (owner-portal-bff is the only repo with a release workflow)"
else while read -r line; do bad "release run $line  → open it → Review deployments → Reject (or Cancel workflow)"; done <<<"$pending"; fi
[ $fail = 0 ] && ok "all 8 repos: no devin PRs, main == demo-baseline"

echo
[ $fail = 0 ] && echo "PREFLIGHT OK — ready to rehearse/demo" || { echo "PREFLIGHT FAILED — fix the ✘ items above"; exit 1; }
