# 0007 — Third-party API keys are injected, never committed

**Status:** Proposed — 2026-10-24 (LOT-000; to be accepted by the maintainer before LOT-056)

## Context
The legacy app hard-codes the Giphy and image-rehost API keys in its Swift sources (audit E §5, D §5). In a public repository they are exposed.

## Decision (proposed)
- Keys are provided at build time through an untracked configuration file (e.g. an `.xcconfig` git-ignored, with a committed `*.example`) and, in CI, through GitHub Actions secrets.
- Engine clients (`HFRNetwork`) take keys and base URLs as parameters; they never read them from source.
- The legacy keys are considered compromised: the maintainer rotates them with the providers.
- Whether to keep a GIF picker (Giphy) is decided in Phase 4.

## Consequences
- A fresh clone builds without keys; features needing them are disabled with a clear message.
- gitleaks and push protection guard against regressions.
