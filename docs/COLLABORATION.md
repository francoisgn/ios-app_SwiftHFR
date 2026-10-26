# Collaboration — repositories, roles, and how an idea becomes code

Decision record: [ADR 0010](adr/0010-upstream-repository-and-contribution-model.md). Engineering rules: [AGENTS.md](../AGENTS.md).
This page is for everyone: maintainers, contributors, and the agents they drive.

## 1. Repositories and branches

| Where | What | Who merges |
|---|---|---|
| `ezzz/HFRnow` → **`dev-swift`** | SwiftHFR integration branch (this codebase). Every SwiftHFR PR targets it | maintainers, green checks required |
| `ezzz/HFRnow` → `master` | Shipped Objective-C app + `HFRswift/` layer. Not SwiftHFR | ezzz |
| `francoisgn/ios-app_SwiftHFR` → `master` | Origin **until handover**, then a fast-forward mirror of `dev-swift` ([§5](#5-mirror-and-backport)) | its admin, through `scripts/sync-upstream.sh` |
| your fork → any branch | Contributors without write access | — |

Until handover, read "`dev-swift`" as `francoisgn/ios-app_SwiftHFR:master`.

## 2. Roles

| Role | Access | Works from |
|---|---|---|
| Owner (ezzz) | Admin of `ezzz/HFRnow`: settings, protection, roles, releases | branches in `ezzz/HFRnow` |
| Maintainer (francoisgn) | Write | branches in `ezzz/HFRnow`, named as in [AGENTS.md §8](../AGENTS.md#8-git-and-pr-workflow) |
| Contributor | Triage recommended; Write when already granted | a fork, whatever the role |
| Agent session | the access of the human driving it, never more | same as its human |

Nobody needs write access to contribute. Forks get the same CI; only secrets are missing, and no required check uses one.
Every PR on `dev-swift` needs one approval from someone other than its author: with Write access, green CI alone would allow self-merges.

## 3. From an idea to a merged feature

```
idea / prototype / mock-up
  └─► issue (feature form)                         anyone
        └─► entry in FEATURES.md (status proposed)  maintainer, with credit to the author
              └─► spec  docs/features/FEAT-XXX.md   author or maintainer — what, why, HFR facts, edge cases
                    ├─► engine lots in LOTS.md        when HFRKit lacks a capability (parsing, network…)
                    └─► app PR(s) on dev-swift            one feature slice per PR, entry criteria below
```

- **Prototypes are welcome and are references, not merge candidates.** A working build in another repository shows the target; the code enters through the steps above, like the legacy app does ([ADR 0004](adr/0004-legacy-app-as-oracle.md)).
- **No guessing about HFR** ([AGENTS.md §3](../AGENTS.md#3-ground-rules)): a feature that reads or writes something new on the forum (a page, a form, a cookie) first gets its protocol facts into `docs/HFR-PROTOCOL.md`, with evidence.
- **Design proposals** (mock-ups, boards) are attached to the issue as images. An adopted design becomes a spec under `docs/features/` with the tokens and states it needs; the boards stay credited to their author.
- **Credit** stays visible: the author of an idea is named in `FEATURES.md`, in the spec, and in the PR that implements it, whoever writes the code.

## 4. Entry criteria for a PR on `dev-swift`

A PR that misses one of these is turned back to draft with a list of what is missing — no partial review.

- [ ] Linked to an issue, a `FEATURES.md` entry or a lot; **one** feature slice or one fix.
- [ ] Branched from the current `dev-swift`, conflict-free; no unrelated changes (formatting, renames, other features).
- [ ] Follows [AGENTS.md §4](../AGENTS.md#4-engineering-conventions); module boundaries respected; nothing forum-related outside `HFRKit`.
- [ ] Tests: engine logic has Swift Testing tests that fail without the change; view logic lives in testable view models.
- [ ] UI changes: before/after screenshots (light, dark, Dynamic Type XL; iPad if the layout changes) in the PR body.
- [ ] CI green, CodeRabbit comments answered, self-review against [LESSONS](agents/LESSONS.md).
- [ ] Docs in the same PR: spec, `HFR-PROTOCOL.md`, ADR when a decision is taken.
- [ ] Agent-written code: author model named, reviewed by a different model ([AGENTS.md §6](../AGENTS.md#6-model-routing-which-agent-does-what)).

### If you build with an agent
Start every session with: *"Read AGENTS.md and docs/COLLABORATION.md and follow them. Work only on <issue/feature>. Write the spec and the tests before the code. Stop and ask when HFR behaviour is not documented."* Then ask a **second** agent, on a different model, to review the diff adversarially before you open the PR. A maintainer can pair with you on the first PR.

## 5. Mirror and backport

After handover `francoisgn/ios-app_SwiftHFR:master` only follows `dev-swift`:

```bash
./scripts/sync-upstream.sh          # dry run: lists the commits to bring in
./scripts/sync-upstream.sh --push   # admin of the mirror: fast-forward origin/master
```

The script refuses when the mirror has diverged; nothing is ever committed on the mirror directly ([ADR 0010 §4](adr/0010-upstream-repository-and-contribution-model.md#4-backport-upstream--francoisgnios-app_swifthfr)).

## 6. CI scope

- Required checks run on `dev-swift` (push and PRs, forks included). `master` keeps its own `wrapper-tests.yml`.
- Weekly CodeQL, Scorecard, Dependabot and issue auto-labelling run only on a repository's default branch: upstream they start at the production switch; until then the mirror runs them.
- Never add `pull_request_target`, and never make a required check depend on a secret.
- **What CI does not catch**: a change that compiles and passes the tests can still break UX, drop a setting, conflict with gestures or rely on an unverified HFR behaviour. Those are stopped by the entry criteria (§4) and the required review, not by green checks.

## 7. Handover checklist

Run once, by the setup session, after the current cloud and Mac rounds are merged here. Repository settings need a repository admin of `ezzz/HFRnow`.

1. `git push https://github.com/ezzz/HFRnow.git master:refs/heads/dev-swift` from an up-to-date clone of this repository (full history, no squash).
2. `REPO=ezzz/HFRnow BRANCH=dev-swift SCOPE=branch REVIEWS=1 ./scripts/configure-repo.sh` — protection, required checks, one approval.
3. Install CodeRabbit on `ezzz/HFRnow` (the required check `review` comes from it) and check that GitHub secret scanning and push protection are on.
4. Open a trivial docs PR from a fork to `dev-swift`: every required check runs and passes without secrets.
5. `./scripts/sync-upstream.sh` here: "already at upstream".
6. Freeze this repository's `master` (mirror only, ADR 0010 §4) and say so in its README.

## 8. Production switch (later)

Decided in its own ADR when SwiftHFR replaces the shipped app: tag `legacy/objc-final` and branch `archive/objc` on the last Objective-C release, then `dev-swift` becomes the default branch and CI follows. The Objective-C code stays readable forever as the blueprint of what works.
