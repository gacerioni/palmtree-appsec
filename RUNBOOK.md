# Palm Tree demo — runbook

The star is **Devin cloud** (Wiki → Ask → Playbook → parallel sessions → Devin Review). The site, /ops/ and GitHub Actions are
the backdrop that proves the work is real. Rehearse end to end at least twice before Oct 5: once slow, once timed (≈12 min live).

## Laptop setup (once)

Everything runs from one directory: this repo is the cockpit, the 8 service repos are subfolders of it.

```bash
git clone https://github.com/gacerioni/palmtree-appsec ~/palmtree && cd ~/palmtree
make clone                                   # 8 palmtree-* repos as subfolders (never edit them by hand)
gh auth status                               # must be gacerioni (make reset / preflight use gh)
python3 -m pip install pyyaml
# ~/.ssh/config, once, so ssh/scp find the key (DEPLOY defaults to ubuntu@3.91.195.25):
#   Host 3.91.195.25
#     User ubuntu
#     IdentityFile ~/.ssh/<bastion-key>.pem
make preflight
```

Optional: `DEVIN_API_KEY` + `DEVIN_ORG_ID` in the environment lets `make dashboard` pick up the Devin sessions for /ops/ and enables
`make kickoff`. You never need `make after` locally: `make refresh` (or Actions → *Refresh Command Center* → Run workflow) does
tests + scanners + before/after + /ops/ deploy in GitHub Actions, ~20 min, no toolchains on the Mac.

Vocabulary: **reset** = everything back to baseline: 8 repos/PRs (`repos-reset`), site release (`site-reset`) and /ops/ (`ops-deploy`);
**preflight** = read-only check that everything is at baseline; **refresh** = rebuild /ops/ from the open PRs (runs in Actions);
**kickoff** = API way to start sessions (you use the Devin UI instead).

## Baseline (start of every rehearsal)

| thing | baseline | how |
|---|---|---|
| 8 service repos, `main` | tag `demo-baseline` (156 findings, 24 critical, `security-gate` red) | `make reset` (or `make repos-reset` alone) |
| https://cognition.platformengineer.io | `5.3.1-e972f71 · stable`, no canary | part of `make reset` (`make site-reset` alone) |
| /ops/ Command Center | baseline numbers, 0 sessions | part of `make reset` (`make ops-deploy` alone) |
| Actions `release` | nothing waiting for approval | reject any pending `promote` |
| Devin cloud | 8 repos indexed in Wiki; playbook `!palmtree_remediate` in the org | one-time setup, survives resets |

`make reset` needs `gh` authenticated as gacerioni and ssh access to the VM. It never touches `palmtree-appsec` on GitHub, the wikis or the playbook.

**`make preflight`** checks all of the above in one go (site tag, no canary, /ops/ at baseline, no `devin/*` PRs, `main == demo-baseline`
in the 8 repos, no `release` run waiting) and prints the fix for anything off. Run it before every rehearsal and on demo morning.

### Exactly what you click on GitHub, live

1. **Merge** the `owner-portal-bff` PR (branch `devin/appsec-dep-jsonwebtoken`, title `appsec(dep:jsonwebtoken): …`; only the PR
   number changes between rehearsals). PR checks: `test` green, `security-gate` red = other campaigns' findings, expected.
2. Nothing. The merge alone starts **one** `release` run: build → GHCR → Trivy → canary 10% → smoke. Reload the site: pill turns amber `CANARY`.
3. **Approve**: Actions → that run → *Review deployments* → `production` → Approve. Pill goes green `STABLE` on the new version.

The other 3 PRs (PyYAML ×2, charging-network-gateway) have no site behind them: show, don't merge. Nobody pushes to `main` except
your Merge, so there is exactly one run to look at.

## T-2h — unattended

```bash
make reset && make preflight
```

Then, **in Devin cloud**, start the sessions you will show *finished*. **One new session per repo** (sidebar → New session, paste, Start,
back to New session, repeat). Never send the second repo inside the first session; there is no "fork", fan-out is just N sessions:

```
!palmtree_remediate repo: gacerioni/palmtree-telemetry-quality-checks, campaign: dep:PyYAML
!palmtree_remediate repo: gacerioni/palmtree-fleet-diagnostics-jobs, campaign: dep:PyYAML
!palmtree_remediate repo: gacerioni/palmtree-owner-portal-bff, campaign: dep:jsonwebtoken
!palmtree_remediate repo: gacerioni/palmtree-charging-network-gateway, campaign: dep:jsonwebtoken
```

(Equivalent from a terminal: `make kickoff ARGS="--campaign dep:PyYAML"` — the API path you *mention* as the GitLab/Jira integration,
not what you type in the room.)

When the 4 PRs are open (~15 min): `make refresh` → ~20 min later /ops/ shows sessions, PRs, before/after. Do not merge anything.
Nobody else is in the loop: playbook ×4 → `make refresh` → done.

Browser tabs, in order: Devin (sessions list) · Devin Wiki of `palmtree-appsec` · site · /ops/ · finished PyYAML session ·
owner-portal-bff PR · owner-portal-bff Actions.

## Live (10–15 min of the 45)

| min | where | you do | you say (EN) |
|---|---|---|---|
| 0 | site | scroll once; footer `v5.3.1-e972f71 · stable` | "Owner portal of a fictional EV maker. Eight services behind it: Java, TypeScript, Python, Go. The company is fake; the CVEs are real." |
| 1 | /ops/ | point at 156 / 24 / 29 campaigns | "Same CVE, many repos. Product Security triages this by hand today. The SLA is the CISO's, not the engineer's." |
| 2 | Devin Wiki | open the wiki of one service; Ask: *"Where is YAML parsed across the Palm Tree repos, and which of those repos have no tests?"* | "Before Devin touches code it already knows the estate. This is the same answer a new hire takes two weeks to find." |
| 4 | Devin Playbooks | open `Palm Tree appsec — remediate one campaign`; scroll the Forbidden Actions | "One playbook, written once. Scope, evidence, and what it must refuse to do." |
| 5 | Devin new session | New session → `!palmtree_remediate repo: gacerioni/palmtree-ota-campaign-service, campaign: dep:snakeyaml` → Start. New session again for `palmtree-warranty-claims-api` (no tests, no owner) | "One session per repo, in parallel. Same playbook. This is the fan-out." |
| 6 | sessions list | the 2 spinning up + the 4 finished ones | "These four finished two hours ago. Let's look at one." |
| 7–9 | finished PyYAML session (fleet-diagnostics-jobs) | plan → test written first (repo had none) → fix → rescan → PR. Scroll to what it left open / refused | "It wrote the test before the fix because the playbook says: no evidence, no PR. And it refused to widen scope." |
| 10 | owner-portal-bff PR | CI `test` green; `security-gate` still red on *other* campaigns; Devin Review comments | "Red gate is honest: one campaign fixed, not all. The order comes from the SLA." |
| 11 | PR | **click Merge** | "A human merges. Always." |
| 11–13 | Actions | `release`: build → GHCR → Trivy image gate → `canary`. Terminal: `for i in $(seq 20); do curl -s https://cognition.platformengineer.io/healthz; echo; done` (≈2 of 20 say `canary`) | "New image, scanned again as an artifact, ten percent of traffic, smoke pinned to the canary. Fails closed, rolls back by itself." |
| 13 | Actions | `promote` waiting → **Approve** → site footer flips to the new tag | "The machine did the work; a human decides. That is what 'safe fix' means here, not a smaller number." |
| 14 | /ops/ | before/after: 156 → 148, PyYAML 4 → 0, jsonwebtoken 2 → 0 | "Velocity you can audit: per finding, a PR, a test, a scan, a deploy." |

Fallbacks: no Actions → run `./canary.sh <tag>` / `./promote.sh` by hand from the VM; no Devin cloud → the finished sessions
are public URLs, the PRs and /ops/ already exist; no internet → screenshots in `report/` from the last `make after`.

## After each rehearsal

```bash
make reset && make preflight
```

Reject any `promote` still waiting in Actions. Wikis and the playbook stay.

## Things that bite

* `make repos-reset` force-pushes the 8 `main`s to `demo-baseline`; it does not trigger `release` (same commit as last push).
* `make baseline` re-tags; only after a deliberate change to a repo's main. Last: owner-portal-bff at `e972f71` (Lucid-style site, PR #6 merged 2026-09-30).
* GHCR package is private: the VM is `docker login`ed. If that expires, `canary.sh` fails closed at pull; site stays 100% stable.
* Required reviewer on `production` is gacerioni; approve from the run page or the GitHub mobile app.
* Wiki indexing after `make repos-reset` is a no-op (same tree). Adding a repo to the wiki live takes minutes: do it only as a gesture, never wait for it.
* Budget per rehearsal: 4 sessions before + 1–2 live.
