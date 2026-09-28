Playbook: Palm Tree appsec — remediate one security campaign in one repository

## Overview
Product Security at Palm Tree Motors groups open Trivy/Semgrep findings into campaigns (same CVE or rule repeated across repositories). This playbook remediates one campaign in one repository and delivers a single reviewable pull request with test and scanner evidence. Run it once per repository in the campaign; sessions run in parallel.

## What's Needed From User
- Repository: `https://github.com/gacerioni/palmtree-<service>` (e.g. `palmtree-fleet-diagnostics-jobs`)
- Campaign id from https://github.com/gacerioni/palmtree-appsec/blob/main/queue/campaigns.json (e.g. `dep:PyYAML`, `dep:jsonwebtoken`, `code:palmtree-ts-jwt-verify-no-algorithms`)

## Procedure
1. Read `queue/findings.csv` in https://github.com/gacerioni/palmtree-appsec and keep only rows whose `repo` matches the target repository and whose `id` belongs to the campaign (`ids` field in `queue/campaigns.json`). Those rows are your scope; nothing else is.
2. Clone the repository and run its test command from `repos.yaml` in palmtree-appsec (`test_cmd` for that repo) to get a green baseline. If there is no test suite, note it for the PR and do step 5 before step 3.
3. Rescan locally and save the output for before/after evidence: `trivy fs --scanners vuln --severity CRITICAL,HIGH --ignore-unfixed .` and `semgrep scan --config <palmtree-appsec>/rules/palmtree-appsec.yml --config p/<language> --config p/secrets --metrics=off .`
4. Dependency findings: bump to the smallest version that clears every CVE listed for that package; prefer the framework bump when the package is transitive (Spring Boot → Tomcat, Fastify → find-my-way). Rebuild and run tests; fix code to match the new API if the bump breaks it. If a bump is genuinely impossible, leave the finding open and say why.
5. Code findings: fix the code, not the rule (parameterized SQL, `yaml.safe_load`/`SafeConstructor`, JWT algorithm allowlist and signing-method check, secrets from the environment, no untrusted free text through Log4j).
6. Repositories without tests: add one minimal characterization test for the code path you changed (the token verifier rejects a token signed with another key, the YAML loader still reads the shipped config, the query still finds the owner's rows). Keep it runnable in CI.
7. Rerun the test command and both scanners. Every finding you claim fixed must be absent from the rescan.
8. Create branch `devin/appsec-<campaign-slug>` (lowercase, `:`→`-`) and open exactly one pull request against `main` with the body below. Do not merge.

## Pull request body (use exactly these sections)
- **Findings addressed**: table with id, package or rule, before → after version or file:line.
- **Findings left open**: id and reason (no fixed version, needs product decision, false positive with proof).
- **Evidence**: before/after Trivy and Semgrep counts, test command and result, tests added.
- **Risk notes**: anything a human should look at before merging (behavior change, major bump, API change).

## Specifications
- One PR per repository, scoped to the campaign's findings only; CRITICAL SLA 15 days, HIGH 30 (the CISO's, not yours).
- Validation: test command green on the PR head; rescan shows the campaign's ids gone for this repo.
- An honest "not fixed, here is why" is worth more than a quiet suppression.

## Forbidden Actions
- Merging, pushing to `main`, editing CI workflows, CODEOWNERS, the rules file, or scanner configuration; adding `nosemgrep`, pins or exclusions to silence a finding.
- New dependencies unless required by a bump. Touching anything outside the target repository.
