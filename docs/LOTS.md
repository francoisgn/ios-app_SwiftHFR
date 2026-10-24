# Migration lots

Single tracking table for the engine migration. Rules: [AGENTS.md §5](../AGENTS.md#5-the-migration-loop-one-lot).
Claim a lot by setting yourself as owner and status `in-progress`, committed and pushed **before** writing code.
Lots come from the [Phase 1 audit](audit/README.md); the "Audit" column maps each lot to the audit proposals it merges.

Statuses: `todo` · `in-progress` · `review` · `done` · `blocked`
Model column: author → reviewer ([AGENTS.md §6](../AGENTS.md#6-model-routing-which-agent-does-what)).
**Fixtures-free** lots (✱) can start before Phase 2: they need no captured page.

## Phase 1 — audit

| Lot | Scope | Module | Difficulty | Model | Depends on | Audit | Owner | Status |
|---|---|---|---|---|---|---|---|---|
| LOT-000 | Audit the legacy engine, split into lots | docs | difficult | Opus → Fable | — | all | cloud/opus (2026-10-24) | review |

## Phase 2 — fixtures and oracle

| Lot | Scope | Module | Difficulty | Model | Depends on | Audit | Owner | Status |
|---|---|---|---|---|---|---|---|---|
| LOT-001 | Fixture capture kit on the Mac + anonymizer (pseudos, cookies, `hash_check`, MP content) | tooling | medium | Sonnet → Opus | — | B6, C8, D9 | — | todo |
| LOT-002 | Oracle exporter: legacy list parsers → JSON | tooling (legacy app) | medium | Sonnet → Opus | 001 | B10 | — | todo |
| LOT-003 | Oracle exporter: legacy topic-page parsing (`LinkItem`, page metadata, actions, `toHTML`) → JSON | tooling (legacy app) | medium | Opus → Fable | 001 | C00 | — | todo |
| LOT-004 | Oracle exporter: forms, write responses, storage formats (synthetic keychain blob, plists, MPStorage JSON) | tooling (legacy app) | medium | Sonnet → Opus | 001 | D9, E fixtures | — | todo |

## Phase 3 — engine

### Models (`HFRModels`)

| Lot | Scope | Module | Difficulty | Model | Depends on | Audit | Owner | Status |
|---|---|---|---|---|---|---|---|---|
| LOT-010 ✱ | List models: forums, topics, flags, pagination, search hits, favourites sections | HFRModels | easy | Sonnet → Opus | — | B1 | — | todo |
| LOT-011 ✱ | Topic page & message models, `MessageActions`, `MessageRenderOptions`, poll | HFRModels | easy | Sonnet → Opus | — | C01 | — | todo |
| LOT-012 ✱ | Form & write models (`ForumForm`, `HopResponse`, `RehostedImage`, AQ) | HFRModels | easy | Sonnet → Opus | — | D1, D2, D10 | — | todo |
| LOT-013 ✱ | Account, stored cookie, settings enums, MPStorage document types | HFRModels | easy | Sonnet → Opus | — | E-3, E-6 | — | todo |
| LOT-014 ✱ | Forum catalogue: category id table, URL aliases | HFRModels | trivial | Haiku → Sonnet | 010 | B2 | — | todo |

### Parsing (`HFRParsing`)

| Lot | Scope | Module | Difficulty | Model | Depends on | Audit | Owner | Status |
|---|---|---|---|---|---|---|---|---|
| LOT-020 ✱ | Parsing core: selector helpers, HFR dates (Europe/Paris), URL helpers, obfuscated-URL decoder, integer extraction, typed errors | HFRParsing | medium | Opus → Fable | 010, 011 | B3, C02, D4 | — | todo |
| LOT-021 | Forum list (home page) parser | HFRParsing | medium | Sonnet → Opus | 010, 020, 002 | B4 | — | todo |
| LOT-022 | Topic list parser (forums, MP, search results) — critical path | HFRParsing | difficult | Opus → Fable | 010, 020, 002 | B5 | — | todo |
| LOT-023 | MP list specifics + unread badge (one parser for the 3 legacy variants) | HFRParsing | easy | Sonnet → Opus | 022 | B6, NET-13 | — | todo |
| LOT-024 | Favourites page parser | HFRParsing | medium | Sonnet → Opus | 022 | B7 | — | todo |
| LOT-025 | Small parsers: search redirect, profile page (hash, avatar), smiley search results, AQ listing | HFRParsing | easy | Sonnet → Opus | 020 | B8, NET-04, NET-12, D6, D9 | — | todo |
| LOT-026 | Poll parser (vote / results / closed) | HFRParsing | medium | Sonnet → Opus | 011, 020 | B9, C07, D11 | — | todo |
| LOT-030 | Message block extraction — core of the topic page | HFRParsing | difficult | Fable → Opus | 011, 020, 003 | C03 | — | todo |
| LOT-031 | Per-message action links (quote, edit, alert, profile, MP, flag, quoteJS) | HFRParsing | medium | Opus → Fable | 030 | C04 | — | todo |
| LOT-032 | Quote analysis (authors, nesting) | HFRParsing | medium | Sonnet → Opus | 030 | C05 | — | todo |
| LOT-033 | Topic page metadata (title, pagination, answer form, hidden fields) | HFRParsing | medium | Sonnet → Opus | 011, 020, 003 | C06 | — | todo |
| LOT-034 | Content normalization (smileys, images, links, signature, code, spoilers) | HFRParsing | difficult | Fable → Opus | 030, ADR 0006 | C08 | — | todo |
| LOT-035 | Video embed detection (fixes the YouTube hour bug) | HFRParsing | easy | Sonnet → Opus | 034 | C09 | — | todo |
| LOT-036 | `hop` form parser (inputs, selects, textarea, entity decoding) | HFRParsing | medium | Sonnet → Opus | 012, 020, 004 | D1 | — | todo |
| LOT-037 | `hop` response classifier (success, rejected, logged out, already alerted) | HFRParsing | medium | Sonnet → Opus | 012, 004 | D2 | — | todo |
| LOT-038 | MPStorage page parsing (locate the storage MP, read its JSON) | HFRParsing | medium | Sonnet → Opus | 023, 030 | D8 | — | todo |

### Network (`HFRNetwork`)

| Lot | Scope | Module | Difficulty | Model | Depends on | Audit | Owner | Status |
|---|---|---|---|---|---|---|---|---|
| LOT-040 ✱ | Transport: protocol + URLSession + mock, form encoding (fixes accent bug), charset decoding, timeouts, typed errors incl. HTTP status | HFRNetwork | easy | Sonnet → Opus | — | NET-01, NET-14 | — | todo |
| LOT-041 ✱ | Endpoint catalogue (typed URL builders) | HFRNetwork | easy | Sonnet → Opus | 040, 014 | NET-02 | — | todo |
| LOT-042 ✱ | Per-account session: isolated cookie jar, `hash_check`, multi-quote cookie (exact id match) | HFRNetwork | medium | Opus → Fable | 040 | NET-03, C16, D4 | — | todo |
| LOT-043 | Login (validate before replacing cookies) | HFRNetwork | medium | Opus → Fable | 042, 025 | NET-04 | — | todo |
| LOT-044 | Session health & refresh (expiry detection, cookie merge) | HFRNetwork | medium | Opus → Fable | 042, 065 | NET-07 | — | todo |
| LOT-045 | Page fetchers: lists and topic page (final URL after redirects) | HFRNetwork | easy | Sonnet → Opus | 041, 042 | NET-08, NET-09 | — | todo |
| LOT-046 | Search: global (meta-refresh flow) and intra-topic (no-redirect flow) | HFRNetwork | medium | Sonnet → Opus | 041, 025 | NET-10, NET-11 | — | todo |
| LOT-047 | MP unread count poll (scheduling stays in the app) | HFRNetwork | easy | Sonnet → Opus | 023, 045 | NET-13 | — | todo |
| LOT-048 | Post-form engine: reply, edit, delete, new topic, new MP, MP reply | HFRNetwork | difficult | Opus → Fable | 036, 037, 042 | D3 | — | todo |
| LOT-049 | Quote engine: quote template, selection formatter | HFRNetwork | medium | Sonnet → Opus | 048, 031 | D4 | — | todo |
| LOT-050 | Moderator alert | HFRNetwork | easy | Sonnet → Opus | 036, 037 | D5 | — | todo |
| LOT-051 | Topic flags & favourites writes | HFRNetwork | medium | Sonnet → Opus | 037, 042 | D7 | — | todo |
| LOT-052 | MPStorage transport (find, read, create, update; conflict-aware) | HFRNetwork | difficult | Opus → Fable | 038, 048, 062 | D8 | — | todo |
| LOT-053 | Smileys: search, wiki, catalogue resource | HFRNetwork | easy | Sonnet → Opus | 025 | NET-12, D9 | — | todo |
| LOT-054 | Poll vote | HFRNetwork | medium | Sonnet → Opus | 026, 037 | D11 | — | todo |
| LOT-055 | AQ client (third-party service) | HFRNetwork | easy | Sonnet → Opus | Q-4 | D6 | — | blocked |
| LOT-056 | Image rehost client (key from configuration) | HFRNetwork | easy | Sonnet → Opus | ADR 0007 | D10 | — | blocked |

### Storage (`HFRStorage`)

| Lot | Scope | Module | Difficulty | Model | Depends on | Audit | Owner | Status |
|---|---|---|---|---|---|---|---|---|
| LOT-060 ✱ | Settings catalogue & store (legacy key names kept) | HFRStorage | easy | Sonnet → Opus | 013 | E-1 | — | todo |
| LOT-061 ✱ | Blacklist / whitelist store (never overwrite with empty) | HFRStorage | medium | Sonnet → Opus | 013 | E-2 | — | todo |
| LOT-062 ✱ | MPStorage document codec & merge | HFRStorage | medium | Opus → Fable | 013 | E-3 | — | todo |
| LOT-063 ✱ | Drafts per context | HFRStorage | easy | Sonnet → Opus | 013 | E-4, D12 | — | todo |
| LOT-064 | Small stores: super-favourites, favourites layout, smiley favourites, histories | HFRStorage | medium | Sonnet → Opus | 013, 004 | E-5 | — | todo |
| LOT-065 | Account & credential store (Keychain, versioned envelope) | HFRStorage | difficult | Opus → Fable | 013, 042 | E-6, NET-05 | — | todo |
| LOT-066 ✱ | Caches: avatars, temporary files, eviction | HFRStorage | easy | Sonnet → Opus | — | E-8, C17 | — | todo |
| LOT-067 | Legacy data import (accounts, lists, settings) | HFRStorage | difficult | Opus → Fable | 060, 061, 064, 065, Q-1 | E-7, NET-06 | — | blocked |

### Gates

| Lot | Scope | Module | Difficulty | Model | Depends on | Audit | Owner | Status |
|---|---|---|---|---|---|---|---|---|
| LOT-070 | Parity gates: differential roll-up, persistence parity checklist, write chapter of HFR-PROTOCOL | docs/tests | medium | Opus → Fable | all parsing/network/storage lots | C18, E-9, D13 | — | todo |

## Phase 4 backlog — app side (not engine)

Pure Swift but app-side, kept here so nothing is lost: visibility policy (BL/WL/filters, C10) · filtered-posts use case (C11) · message HTML builder (C12) · page shell & resources (C13) · typed JS bridge (C14) · message action policy (C15) · image/GIF decoding (E-8) · background MP check scheduling (NET-13) · Giphy (E-10).
