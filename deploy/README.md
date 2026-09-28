# Demo host: cognition.platformengineer.io

One VM (today: AWS us-east-1, `ubuntu@3.91.195.25`, Ubuntu, 1 vCPU/2 GiB), Docker Compose, Caddy with Let's Encrypt.

```
cognition.platformengineer.io/        Palm Tree Motors site   (image: ghcr.io/gacerioni/palmtree-owner-portal-bff)
cognition.platformengineer.io/ops/    Remediation Command Center (static, from dashboard/)
```

## First time (≈10 min)

1. Cloud: create the VM, allow **tcp/80 + tcp/443** in its security group, note the external IP (keep it static).
2. GoDaddy: **A record** `cognition` → that IP. Wait for `dig +short cognition.platformengineer.io` to answer.
3. On the VM:
   ```bash
   curl -fsSL https://raw.githubusercontent.com/gacerioni/palmtree-appsec/main/deploy/bootstrap.sh | bash
   newgrp docker
   cd ~/palmtree-appsec/deploy && cp .env.example .env && $EDITOR .env   # DOMAIN, ACME_EMAIL, SITE_STABLE_TAG
   docker compose up -d --build
   ```
   Caddy gets the certificate on first request. `docker compose logs -f caddy` if it does not.
   The GHCR package is private by default: `docker login ghcr.io` on the VM with a read:packages token,
   or flip the package to Public (GitHub → Packages → palmtree-owner-portal-bff → Package settings).
4. Deploy key + GitHub secrets (`DEPLOY_HOST`, `DEPLOY_USER`, `DEPLOY_SSH_KEY`), without ever printing the key:
   ```bash
   ssh $VM 'ssh-keygen -t ed25519 -N "" -C palmtree-deploy -f ~/.ssh/palmtree-deploy && cat ~/.ssh/palmtree-deploy.pub >> ~/.ssh/authorized_keys'
   DEPLOY_SSH_KEY="$(ssh $VM cat ~/.ssh/palmtree-deploy)" GITHUB_TOKEN=... ./set_gh_secrets.py gacerioni/palmtree-owner-portal-bff <ip> ubuntu
   ```
   Settings → Environments → `production` → **Required reviewers: you** (needs a public repo on the free plan).
   That click is the "human approves the release" moment in the demo.

## Every demo day

```bash
make dashboard            # locally: refresh dashboard/data.json, then
make ops-deploy           # scp it to the VM and rebuild the ops container
```

## Release flow (`.github/workflows/release.yml` in the portal repo)

```
merge to main → build image → push ghcr.io/…:<version>-<sha> → Trivy image gate (CRITICAL blocks)
  → ssh VM: canary.sh <tag>  (10% traffic, smoke pinned to canary, fails closed)
  → environment "production": waits for Approve
  → ssh VM: promote.sh       (stable = new tag, 100%, canary removed)
```

First real run of the gate caught CVE-2026-59873 (node-tar bundled with npm in `node:20-alpine`); fix was to drop npm
from the runtime stage of the Dockerfile. Good story for the room: the gate protects the artifact, not just the source.

## The canary, by hand (what the workflow does)

```bash
./canary.sh 5.4.0-abc1234   # pull, start canary, wait healthy, Caddy 9:1, smoke pinned to canary
./promote.sh                # stable takes the new tag, canary removed, smoke on stable
./rollback.sh               # any time: 100% stable
```

Watch it: reload the site footer badge (`vX · stable` / `vY · canary`), or `for i in $(seq 20); do curl -s https://$DOMAIN/healthz; echo; done`.
`curl -H 'X-Canary: 1' https://$DOMAIN/healthz` pins to the canary.

Nothing here has credentials. `.env` stays on the VM (gitignored).
