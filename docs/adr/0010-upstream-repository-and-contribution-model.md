# 0010 — Upstream repository, contribution model and legacy archive

**Status:** Proposed — 2026-10-26 (needs the agreement of ezzz, owner of the upstream repository)

## Context
- The community app lives in [`ezzz/HFRnow`](https://github.com/ezzz/HFRnow): `master` carries the shipped Objective-C app and its `HFRswift/` SwiftUI layer, with its own CI (`wrapper-tests.yml`).
- SwiftHFR was started in `francoisgn/ios-app_SwiftHFR` with a strict process (specs, oracle, differential tests, ADRs, reviews). It must move to the community repository without losing that process, and without disturbing the shipped app.
- New contributors arrive with different practices. The first one (Bybifok, `moust4ki`) builds UI-first with an agent, without specs, tests or adversarial review, and opened PRs #3–#6 on `ezzz/HFRnow:master`.
- Collaboration on the upstream repository may stall; the maintainer wants to keep a copy of everything merged upstream.
- GitHub facts that constrain the design (checked 2026-10):
  - PRs from forks run `pull_request` workflows **without secrets** and with a read-only token.
  - Scheduled (`cron`) workflows, `issues` events, Dependabot version updates and Scorecard run **only from the default branch**; `push` and `pull_request` triggers work on any branch.
  - Workflows of a `pull_request` run come from the PR's merge result, so PRs targeting a branch run that branch's workflows.
  - A PR opened with `GITHUB_TOKEN` does not trigger other workflows.

## Decision

### 1. Upstream branch
- SwiftHFR moves to `ezzz/HFRnow` as a long-lived branch **`swift`**, created by pushing `francoisgn/ios-app_SwiftHFR:master` **with its full history** (shared history makes every later sync a plain merge).
- `swift` is the integration branch until the production switch. `master` stays the shipped Objective-C app and is not touched by SwiftHFR work.
- Handover happens once the current cloud and Mac rounds are merged in `francoisgn/ios-app_SwiftHFR` (iso content), not before.

### 2. Who works where
| Role | Where they push | PR target |
|---|---|---|
| Maintainers with write access (ezzz, francoisgn) and their agent sessions | branches in `ezzz/HFRnow` (`lot/…`, `fix/…`, `feat/…`, `chore/…`, `docs/…`, `claude/…`) | `swift` |
| Everyone else, including invited contributors without engineering experience | their own fork | `swift` |

- Contributing never requires write access. A contributor invited to the repository gets the **Triage** role (labels, issues), not Write.
- Branch protection on `swift` is the one of [`scripts/configure-repo.sh`](../../scripts/configure-repo.sh) (PR, required checks, resolved conversations, linear history, no force push), applied by the owner with `SCOPE=branch` so the repository's own settings are not touched.
- PRs to `master` that change SwiftHFR scope are redirected to `swift`.

### 3. CI
- Workflows live on `swift`; `ci`, `codeql` and `labels` trigger on `push` to `master` **and** `swift`, so the same files work in both repositories.
- Every required check must pass **without secrets** (fork PRs). `pull_request_target` with a checkout of PR code is forbidden.
- Default-branch-only automation (weekly CodeQL, Scorecard, Dependabot, issue auto-labelling) is inactive upstream until the production switch; during the transition it keeps running in `francoisgn/ios-app_SwiftHFR`, which receives every upstream change (§4).
- `master`'s `wrapper-tests.yml` is left as is.

### 4. Backport (upstream → `francoisgn/ios-app_SwiftHFR`)
- After handover, `francoisgn/ios-app_SwiftHFR:master` is a **downstream mirror** of `ezzz/HFRnow:swift`: same commits, same SHAs.
- Sync = **fast-forward only**, with [`scripts/sync-upstream.sh`](../../scripts/sync-upstream.sh), run by the mirror's admin (branch protection does not bind admins there, `enforce_admins: false`). A PR cannot do it: the mirror allows squash merges only and requires linear history, and a squash would rewrite upstream SHAs and break every later sync. CI runs on the mirror after the push.
- If the fast-forward is refused, the mirror has diverged: the script stops, nothing is merged by hand. Commits found only on the mirror are opened as PRs on `swift`; once merged there, the owner realigns the mirror on upstream (a force push: consequential, confirmed first — AGENTS.md §0). The rule below exists so this never happens.
- No work lands on the mirror after handover, including urgent fixes: they go to `swift`.

### 5. Feature intake
Ideas, prototypes and PRs from contributors enter through [COLLABORATION.md](../COLLABORATION.md#3-from-an-idea-to-a-merged-feature): issue → feature entry in [FEATURES.md](../FEATURES.md) → spec → engine lots if needed → PR that meets the entry criteria. Prototype code is a reference, like the legacy app, not code to merge as is. Authors keep the credit for their ideas ([research/bybifok-proposals.md](../research/bybifok-proposals.md), `CREDITS.md`).

### 6. Legacy Objective-C archive
At the production switch (separate ADR):
- tag `legacy/objc-final` on the last `master` commit that shipped the Objective-C app, and branch `archive/objc` from it (protected, read-only);
- `swift` becomes the default branch content; CI moves with it.
The archive stays the functional blueprint and the oracle of [ADR 0004](0004-legacy-app-as-oracle.md). Until then, oracle exports name the legacy commit they ran on.

## Consequences
- One integration branch, one process: the rules in `AGENTS.md` apply upstream unchanged.
- The shipped app and SwiftHFR never share a PR; nothing in SwiftHFR work can break a TestFlight build.
- Maintainers keep fast branches with full CI; outsiders get the same checks through forks, minus secrets — which no required check uses.
- Default-branch automation is missing upstream until the switch; the mirror covers it.
- Code from contributors' own repositories is ported through lots, not merged wholesale. Copying files from an MPL-2.0 project (e.g. `moust4ki/ultra-hfr`) keeps those files under MPL-2.0; the author can instead contribute their own code under this project's license through a PR (CONTRIBUTING.md).
- The owner of `ezzz/HFRnow` must apply branch protection, roles and repository settings; agents cannot (AGENTS.md learnings, 2026-10-24).
