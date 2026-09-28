# Palm Tree demo — runbook (reset → kickoff → PR → merge → canary → promote)

Everything below is idempotent. Run it end to end at least twice before Oct 5: once slow (learn it), once timed (≈12 min live).

## State you start every rehearsal from

| thing | baseline | how it gets there |
|---|---|---|
| 8 service repos, `main` | tag `demo-baseline` (155 findings, 24 critical, `security-gate` red) | `make reset` |
| open `devin/*` PRs | none | `make reset` (closes + deletes branches) |
| https://cognition.platformengineer.io | `5.3.1-49e1a29 · stable`, no canary | `ssh VM 'cd palmtree-appsec/deploy && ./reset-site.sh 5.3.1-49e1a29'` |
| /ops/ Command Center | baseline numbers, 0 sessions | `make dashboard && make ops-deploy DEPLOY=ubuntu@3.91.195.25` |
| GitHub Actions `release` | none waiting for approval | reject/approve any pending `promote` in the Actions tab |

`make reset` needs `gh` authenticated as gacerioni on your laptop (`gh auth status`). It never touches `palmtree-appsec`.

## T-2h (before the room) — the slow part runs unattended

```bash
cd ~/repos/palmtree            # or wherever palmtree-appsec is cloned, with the 8 repos next to it (make clone)
make reset
ssh ubuntu@3.91.195.25 'cd palmtree-appsec/deploy && ./reset-site.sh 5.3.1-49e1a29'
make dashboard && make ops-deploy DEPLOY=ubuntu@3.91.195.25
make kickoff ARGS="--campaign dep:PyYAML"        # 2 sessions, the ones you will *show finished*
make kickoff ARGS="--campaign dep:jsonwebtoken"  # 2 sessions: owner-portal-bff + charging-network-gateway (the one you merge live)
```

Sessions take 10–25 min. When the PRs are open: `make status`, then `make after` (reruns tests + scanners on each PR head) and
`make dashboard && make ops-deploy DEPLOY=…` so /ops/ already shows sessions, PRs and before/after. Do **not** merge anything yet.

Keep one browser window with tabs, in this order: site · /ops/ · Devin sessions list · the finished PyYAML session · the
owner-portal-bff PR · Actions tab of owner-portal-bff.

## Live (10–15 min inside the 45)

| min | you do | you say (EN) |
|---|---|---|
| 0 | site tab; scroll once; footer shows `v5.3.1-49e1a29 · stable` | "This is the owner portal. Behind it, eight services in Java, TypeScript, Python and Go. It's fictional, but the vulnerabilities are real CVEs." |
| 1 | /ops/ tab | "155 critical and high findings, grouped into 28 campaigns. Same CVE, many repos. Your product-security team triages this by hand today." |
| 2 | `make kickoff ARGS="--campaign dep:lodash"` in a terminal (1 session) — the *starting* one | "One playbook, one campaign, N repos. Devin gets a session per repo, in parallel." |
| 3 | Devin sessions list: the new one spinning up + the 4 finished ones | "These finished two hours ago. Let's look at one." |
| 4–6 | finished PyYAML session: plan → test written first (repo had none) → fix → scanner rerun → PR. Show what it refused to touch | "It wrote the test before the fix, because the playbook says: no evidence, no PR. And it refused to widen scope." |
| 7 | owner-portal-bff PR (jsonwebtoken): CI `test` green, `security-gate` still red on *other* findings; Devin Review comments | "The gate is red because we fixed one campaign, not all. That's honest. The CISO's SLA decides the order." |
| 8 | **click Merge** | "A human merges. Always." |
| 8–11 | Actions tab: `release` → build → GHCR → Trivy image gate → `canary` job. Meanwhile: `for i in $(seq 20); do curl -s https://cognition.platformengineer.io/healthz; echo; done` shows ~2 of 20 `canary` | "New image, scanned again as an artifact, ten percent of traffic, smoke test pinned to the canary. If anything fails it rolls back on its own." |
| 11 | `promote` waiting → **click Approve** → footer flips to the new tag | "The machine did the work; a human decides. That's the fix being safe, not just the count going down." |
| 12 | /ops/ before/after: 155 → 14x, PyYAML 4 → 0, jsonwebtoken 2 → 0 | "Velocity you can audit: PR, test, scan, deploy, per finding." |

Fallbacks (no network, Actions slow): the canary/promo can be done by hand from the VM (`./canary.sh <tag>`, `./promote.sh`),
and the finished sessions + PRs + /ops/ are already there. Screenshots/video of a full run live in `report/` after `make after`.

## After the room / after each rehearsal

```bash
make reset
ssh ubuntu@3.91.195.25 'cd palmtree-appsec/deploy && ./reset-site.sh 5.3.1-49e1a29'
```

If the live merge went through, the new image tag exists in GHCR; `reset-site.sh` puts stable back to the baseline tag anyway.

## Things that bite

* `make reset` force-pushes `main` of the 8 repos to `demo-baseline`; that does not trigger `release` (same commit as the last push).
* Re-tag the baseline (`make baseline`) only after a deliberate change to a repo's main. Last re-tag: owner-portal-bff at `49e1a29` (site + release workflow).
* GHCR package is private today: the VM is `docker login`ed. If the login expires, `docker pull` fails inside `canary.sh` → fails closed, 100% stable.
* Required reviewer on `production` is gacerioni; approve from the Actions run page or the GitHub mobile app.
* Budget: every rehearsal = 4–5 Devin sessions (2 PyYAML + 2 jsonwebtoken + 1 live). `--all` is 8.
