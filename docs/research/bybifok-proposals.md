# Bybifok — handover file

For **Bybifok** (GitHub [`moust4ki`](https://github.com/moust4ki)). One-time handover: take this file, then work on **`ezzz/HFRnow`, branch `dev-swift`**. This file is not maintained after 2026-10-27.
Reviewed 2026-10-26 from your proposal message, your PRs [ezzz/HFRnow#3](https://github.com/ezzz/HFRnow/pull/3)–[#6](https://github.com/ezzz/HFRnow/pull/6) and your prototype [moust4ki/ultra-hfr](https://github.com/moust4ki/ultra-hfr). Everything below stays credited to you; you get the credit by implementing it through your PRs.

## 1. What is already in the shared docs, with your name

- **Protocol facts** you found (B1–B10) and **feasibility questions** (B11–B15): `docs/HFR-PROTOCOL.md` §7b on `dev-swift` ([ezzz/HFRnow#11](https://github.com/ezzz/HFRnow/pull/11) until merged). Settle one with a captured, anonymized page (`docs/FIXTURES.md`): high value, it unblocks lots.
- **Contribution model**: [ADR 0011](https://github.com/ezzz/HFRnow/pull/10) — fork, PR into `dev-swift`, one approval by someone else, idea → spec → lots → PR.
- **Real legacy bugs** from your PR #3, as SwiftHFR work to claim (§7): issues to be opened on `ezzz/HFRnow` once Issues are enabled there.

## 2. Your features to spec (FEAT-001…021)

Spec one at a time in `docs/features/FEAT-XXX.md` on `dev-swift`: what and why, screens and states (light, dark, Dynamic Type XL, iPad), HFR facts with their source, edge cases, engine lots needed (`docs/LOTS.md`), legacy settings kept. Attach your design boards to the feature issue. Start with the `high` ones whose engine lots are done or close (FEAT-002, 001, 006, 008, 007, 009). App code waits for the app target (LOT-080) and the lots each feature needs.

| Id | Feature | Engine dependencies | Open questions | Phase | Priority | Owner | Status |
|---|---|---|---|---|---|---|---|
| FEAT-001 | **Home / "À suivre"**: resume last reading, unread MPs, super favourites, favourites, flags with news grouped by category, Alertes Qualitaÿ; first sidebar entry on iPad. Replaces the Favoris tab ("Tout" opens the current favourites screen) | 023, 024, 055, 064, **new** reading-position store (HFRStorage) | Migration of the legacy "start screen" and "favourites mode" settings (LOT-060/067) | 4 | high | — | proposed |
| FEAT-002 | **Page navigator** from the page number in the topic title: "Aller à la page…", first/last, ±5 around current, blocks of 50; all pages listed up to 30 | 033 | — | 4 | high | — | proposed |
| FEAT-003 | **Honest list paging**: "Page N" without a fake total in forum lists, "Dernière page" disabled when unknown; exact page count per topic row kept | 022, **new** `PageNavigation` exactness flag (HFRModels) | Protocol fact to capture (window pager vs `sujetCase4`) | 3–4 | high | — | proposed |
| FEAT-004 | **Page scrubber** on the right of a topic: bubble "p. N", jump on release, dot and snap at first-unread page, haptic every 100 pages | 022/024 (flag page), 033 | Accessibility (VoiceOver adjustable action) | 4 | medium | — | proposed |
| FEAT-005 | **"Vérifier HFR" App Intent**: background check of MPs and flags, local notification, run by Shortcuts automations | 044, 047, 065, **new** "check updates" flow (HFRClient) + "already notified" state (HFRStorage) | Minimum interval (politeness), never GET a topic page (flags), keep the legacy BGTask (LOT-047) | 4 | medium | — | proposed |
| FEAT-006 | **Quote tray and quick-reply bar**: count of checked quotes, reply takes them in topic order, tray emptied after a confirmed send | 042, 048, 049 | — | 4 | high | — | proposed |
| FEAT-007 | **"Nouveau" banner** at the first unread message; stable position while images load and after a network error | 022, 030 | — | 4 | high | — | proposed |
| FEAT-008 | **Uniform swipes** in every list: Lu (with "Annuler", stays until refresh), Dernière page, Super favori, Retirer | 045, 051, 064 | "Annuler" needs the previous flag URL | 4 | high | — | proposed |
| FEAT-009 | **Session expiry sheet**: draft kept, resent after re-login only when the server confirmed it was not posted | 037, 044, 048, 063 | Double-post risk | 4 | high | — | proposed |
| FEAT-010 | **Appearance**: darker dark (#0B0B0C), OLED black, 1 pt separators, compact mode, one-line message header, single accent colour, live preview in settings, seasonal themes | 060 | Keep the legacy brightness and accent settings or migrate them | 4–5 | medium | — | proposed |
| FEAT-011 | **Image loading setting**: never / Wi-Fi / always | 060 (`ImageDisplayMode` exists) | — | 4 | medium | — | proposed |
| FEAT-012 | **Emoji refusal with smiley suggestion** | 012, 048, **new** emoji→smiley table | HFR truncates at the first non-BMP character, BMP emoji untested | 3–4 | medium | — | proposed |
| FEAT-013 | **Preview before send** (exact BBCode rendering) | **new** BBCode renderer | Module (HFRParsing or app) — ADR needed | 4 | medium | — | proposed |
| FEAT-014 | **HD gallery** with swipe between images | 034, 056 | — | 4 | medium | — | proposed |
| FEAT-015 | **State restoration**: forum, topic, page, position on return, fold, multi-window | **new** reading-position store | — | 4–5 | medium | — | proposed |
| FEAT-016 | **iPhone Duo / iPad columns**: two columns unfolded, tabs in a rail folded, sidebar pinned or on demand | — | Phase 5 design documentation | 5 | high | — | proposed |
| FEAT-017 | **Continuous scrolling** (option, off by default, haptic per page) | 045, 030–034 | 🔴 Flag semantics: an authenticated GET moves the flag; prefetch without session then reload — two requests per page | 5 | low | — | proposed |
| FEAT-018 | **"On t'a cité"** in Home and in the FEAT-005 notification | capture of `quote_only=1` first | No server signal known; feasibility study before any promise | 5+ | low | — | proposed |
| FEAT-019 | **Upload history with server-side delete** on reho.st | 056, 071 | No delete API evidenced for guest uploads | 4+ | low | — | proposed |
| FEAT-020 | **Opening HFR links in the app** (share, clipboard, universal links) | 020 | Q-1 decided (update of `hfrplus.red.super`): the site's AASA already names this App ID, so universal links are possible — verify on device | 4 | high | — | proposed |
| FEAT-021 | **iPad keyboard shortcuts** (J, K, Q, R, ⌘F) and **Spotlight** for read topics (from ultra-hfr) | — | — | 5 | low | — | proposed |

## 2b. Ideas and UX we did not have (source of each feature)

| Idea | Where you showed it | Feature |
|---|---|---|
| Home / "À suivre": everything new on one screen, resume reading | message; ultra-hfr "Le Fil" (`UltraHFR/Feed/`) | FEAT-001 |
| Page navigator from the title (±5, blocks of 50) | message; PR #6 | FEAT-002 |
| Honest list paging ("Page N", "Dernière page" disabled) | PR #3 | FEAT-003 |
| Page scrubber with first-unread dot and haptics | message; ultra-hfr `Reader/PageScrubber.swift` | FEAT-004 |
| Serverless notifications through a Shortcuts App Intent | message | FEAT-005 |
| Quote tray with count, topic order, emptied after send; draft + quotes merge | message; ultra-hfr `Reader/QuoteTray.swift` | FEAT-006 |
| Same swipes in every list, "Lu" with "Annuler" | message; PR #6 ("Dernière page" swipe) | FEAT-008 |
| Session expiry sheet keeping the draft | message | FEAT-009 |
| Darker dark, OLED, 1 pt separators, one-line header, single accent, live preview in settings, smiley scale, avatar colour from the pseudo | message; PRs #5–#6; ultra-hfr `HFRDesign` | FEAT-010 |
| Emoji refused with a smiley suggestion | message | FEAT-012 |
| Exact BBCode preview | ultra-hfr `HFRContent` (`BBCodeParser`, `BBCodeWriter`) | FEAT-013 |
| State restoration on fold / multi-window; iPhone Duo two columns and rail | message; PR #4; ultra-hfr `RootLayout` | FEAT-015, FEAT-016 |
| Continuous reading with at most 10 pages in memory | ultra-hfr | FEAT-017 |
| iPad keyboard shortcuts, Spotlight for read topics | ultra-hfr | FEAT-021 |
| Search help when a word is shorter than 4 letters; refresh that stays on the current page; pull to refresh on categories; "Connexion requise" alert; active-filter summary with "Tout afficher"; categories grouped by family | PR #3, PR #6 | Phase 4 details |
| Design document: colour tokens, 4.5:1 contrast targets | PR #5 | Phase 5 design input |

## 3. Engineering patterns worth porting (through our lots)

| Pattern | ultra-hfr source | Target |
|---|---|---|
| At most 2 concurrent requests to HFR, identifiable User-Agent | `HFRKit` client (actor + limiter) | LOT-040 / LOT-045 |
| Parsing off the client actor (`@concurrent`) | `HFRKit` | LOT-045 |
| Prefetched pages fetched **without** session, current page reloaded with session (flags never advanced behind the reader) — same principle as our LOT-045 | decision D6 | LOT-045, FEAT-017 |
| Reading position that only moves forward; "since your visit of …" | decisions D8–D9 | new reading-position store (FEAT-001, FEAT-015) |
| Message content as a typed tree rendered to our own HTML, everything escaped | decision D5, `HFRContent`, `HFRReader` | input for the ADR to take before LOT-034 (revisits ADR 0006 option 1) |
| Reader tests with a stub `URLProtocol` and a fake page driver | `UltraHFRTests` | Phase 4 test strategy |
| Feed refresh at most every 2 minutes when logged in | decision D11 | FEAT-001, FEAT-005 |

## 4. Protocol facts

Moved to `docs/HFR-PROTOCOL.md` §7b (B1–B10, B11–B15) with your name. Not kept: the `[quotemsg=numreponse,page,0]` format — our captures (`R41a`, `R41b`, `R47a`) show `numreponse,ref,<quoted member id>`; the empty smiley-search result — our `R53c` shows a "Désolé…" text.

## 5. Legacy features the proposals do not mention

"All current functions" stay in scope. Checked in the legacy code; none may disappear silently:
multi-account · blacklist and whitelist · MPStorage sync · bookmarks · post filter · MP actions (new MP, mark unread, delete) · new topic, edit and delete own posts · moderator alert · AQ creation · poll vote and poll draft · archived drafts · "+" button modes · Giphy · automatic background MP check (BGTask) — FEAT-005 adds to it, does not replace it · **account deletion** (App Store 5.1.1(v)) · start-screen and favourites-mode settings · multi-window · the legacy "swipe changes page" setting (on by default; your proposal removes the gesture — keep the setting, default to be decided).

## 6. Claims checked

| Claim | Verdict |
|---|---|
| HFR gives no total page count in topic lists | 🟠 True for the list pager, false for each topic (row `sujetCase4`) |
| No universal links: the site publishes no `apple-app-site-association` | 🔴 False: the AASA exists (old format) and names the legacy App ID `QMG83DG7YP.hfrplus.red.super` (checked live 2026-10-26). Universal links work for a release under that App ID (Q-1), not for a third-party app |
| HFR cuts a message at the first emoji | 🟢 At the first non-BMP character (HFR-PROTOCOL, `W12`); BMP emoji untested |
| Upload deletion on reho.st | 🔴 No delete API evidenced for guest uploads |
| No instant push | 🟢 |

## 7. Your PRs on `ezzz/HFRnow:master` (#3–#6)

They target the **shipped Objective-C app**, not SwiftHFR: merging them is ezzz's decision. Our review (static only, no build possible on Linux; no CI ran on them; all start from tag `4.0`, 43 commits behind `master`):

| PR | Content | Verdict |
|---|---|---|
| #3 Bug fixes | real legacy bugs (nil crash in list parsers, pager index, `liste_sujet` paging, AQ entities, bookmarks open page 1, list jump on refresh) | 🟠 Cherry-pick: `237db70`, `a817498`, `9935b98`, `dc93420` apply cleanly. Blockers: a committed `Carthage/Build` symlink to the author's machine; "Link"→"Lien" breaks `MessagePopupMenuPolicyTests.swift:48,128`; a nil image `src` can mark a flag "red" |
| #4 iPhone Duo | Duo inner/outer screens, workarounds for iOS 27.1 freezes, `displayScale` instead of `UIScreen.main` | 🟠 Keep the workarounds; `b1f07e2` removes `TabBarReselectionObserver` and conflicts with `c1e1424` |
| #5 "Natif calme" reskin | ~95 % visual, +2.5 k lines, no tests | 🔴 Not as is: `[code]` blocks lose monospace (`!important` rule), user accent colours overwritten, brightness/tint settings removed (just restored on `master`), fixed font sizes |
| #6 Sidebar, page menu, single colour | replaces the iPad split navigation just finished on `master` (HFR-006) | 🔴 Not as is: custom back-gesture delegate makes other gestures fail, `onAppear` counter can drift, filter summary counts only the current page |

Fixes from #3 are also **non-regression tests to write** in SwiftHFR (LOT-022, 025, 041, 046).

**Backport to `master`** (the shipped app) is your call with ezzz: the cherry-pickable commits of #3 are listed above.
**In SwiftHFR**, the real bugs of #3 become these issues (to open once Issues are enabled on `ezzz/HFRnow`; claim one and propose the PR):

| Legacy commit | SwiftHFR work | Area | Lot |
|---|---|---|---|
| `237db70` | Topic-list pager: a link without `href` must not break the parser (test + fix) | parsing | LOT-022, 021 |
| `a817498` | Topic-list page N must really load page N (`liste_sujet` paging) | network | LOT-041 |
| `dc93420` | No fake total page count from the windowed pager | parsing | LOT-022 |
| `a817498` | AQ RSS: decode HTML entities in titles, authors, comments | parsing | LOT-025 (blocked by Q-4) |
| `246a9c7` | Links to a post (AQ, bookmarks) open its page and `#t` anchor, not page 1 | app | LOT-020, 045, 083 |
| `246a9c7` | Refresh reloads the current page and keeps content meanwhile | app | LOT-082, 083 |
| `be196f8` | A cancelled topic request never completes the next load; show at `DOMContentLoaded` | app | LOT-083 |

## 8. Licence

ultra-hfr is MPL-2.0 (file-level copyleft); SwiftHFR is PolyForm Noncommercial. Copied files would stay MPL-2.0. Preferred path: ideas and facts are ported through our lots with credit; when you submit your own code by PR, you contribute it under this project's licence (CONTRIBUTING.md on `dev-swift`). Any wholesale import needs an ADR amending ADR 0003.

## 9. Prompt to paste into your agent

```text
You work on SwiftHFR, a native iOS client for forum.hardware.fr.
Repository: https://github.com/ezzz/HFRnow — branch dev-swift ONLY. The default branch master is the legacy app:
never branch from it, never target it, and ignore its CLAUDE.md.

Setup:
1. Fork ezzz/HFRnow, clone your fork, then: git fetch origin dev-swift && git switch dev-swift
2. Read and follow, in this order: AGENTS.md, docs/adr/0011-contribution-model-and-feature-intake.md,
   docs/HFR-PROTOCOL.md (§7b lists the facts I reported), docs/FIXTURES.md, docs/LOTS.md.
3. Read my handover file once (I give it to you): it lists my features (FEAT-001…021), my PRs #3–#6 and the bugs to fix.
4. Create every branch from dev-swift, open every PR against dev-swift on ezzz/HFRnow.

Task: <ONE item: "spec FEAT-002 page navigator", "settle fact B2 with a capture", "issue: <title>">.

Rules:
- One item per PR, linked to its issue. Credit me (Bybifok) in the PR.
- Never guess how HFR behaves: every URL, form field, cookie or selector comes from the legacy code (master) or a captured page.
  If it is not documented, stop and tell me what to capture.
- Captured pages are anonymized (docs/FIXTURES.md) and checked by someone else before any push. No secrets, cookies or real pseudos.
- Spec: docs/features/FEAT-XXX.md with screens and states, HFR facts with their source, edge cases, engine lots needed, legacy settings kept.
- Code: tests first (Swift Testing), view logic in testable view models, AGENTS.md §4 conventions, AGENTS.md §9 definition of done.
- Before opening the PR, self-review against docs/agents/LESSONS.md and name the model that wrote it.
- Then I ask a second agent, on a different model, to review the diff adversarially. Do not merge: someone else approves.
```
