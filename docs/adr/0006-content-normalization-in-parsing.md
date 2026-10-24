# 0006 — Message content normalization lives in HFRParsing

**Status:** Proposed — 2026-10-24 (LOT-000; to be accepted by the maintainer before LOT-034)

## Context
Message content must be rewritten before display: smileys, images (incl. rehost rewrites), relative links, signature split, code blocks, video embeds (audit C §4).
The legacy app does this with regexes over libxml2's serialized HTML, which is fragile.
Doing it on the DOM requires an HTML parser, and ADR 0002 confines SwiftSoup to `HFRParsing`.

Options:
1. Normalize in `HFRParsing`, driven by a value-type `MessageRenderOptions` defined in `HFRModels`.
2. Relax ADR 0002 and let the app (or a feature module) use SwiftSoup.
3. Keep regex rewriting app-side.

## Decision (proposed)
Option 1. `HFRParsing` returns, per message, normalized content HTML **plus** typed lists (images, smileys, links, embeds, signature HTML), so the app never re-parses HTML.
Display policy (blacklist, whitelist, filters) stays out of the parser and is applied app-side on the parsed messages.

## Consequences
- SwiftSoup stays confined; the riskiest transformations are Linux-testable against fixtures.
- Options that change rendering (image mode, embeds) require re-parsing, which is acceptable: parsing is fast and pages are small.
- `MessageRenderOptions` becomes part of the public engine API and must stay small and explicit.
