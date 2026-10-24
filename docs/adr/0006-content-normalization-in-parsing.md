# 0006 — Message content normalization lives in HFRParsing, display-independent

**Status:** Proposed — 2026-10-24 (LOT-000, revised after review F-ADR0006; to be accepted by the maintainer before LOT-034)

## Context
Message content must be rewritten before display: smileys, images (incl. rehost rewrites), relative links, signature split, code blocks, spoilers, video embeds (audit C §4).
The legacy app does this with regexes over libxml2's serialized HTML, which is fragile, and inserts some values unescaped into a `WKWebView` that has file read access (C §5.2, C 6.3).
DOM-level work needs an HTML parser, and ADR 0002 confines SwiftSoup to `HFRParsing`.

Options considered:
1. **Normalize in `HFRParsing`, display-independent**: the parser emits normalized, sanitized content HTML plus typed lists (images, smileys, links, embeds, quotes, spoilers, signature). Display choices are applied later by the app's HTML builder on those lists.
2. Normalize in `HFRParsing` driven by display options (`MessageRenderOptions`). Rejected: every settings change would require re-parsing, and oracle comparisons would depend on settings.
3. A typed content AST (text, image, smiley, link, quote, spoiler, code blocks) rendered by the app. Best testability and removes HTML string handling entirely, but means rewriting ~1,077 lines of tuned CSS-driven rendering. Rejected for now; can supersede this ADR later.
4. Relax ADR 0002 so the app uses SwiftSoup. Rejected: spreads the riskiest dependency.
5. Keep regex rewriting app-side. Rejected: it is the source of the legacy bugs.

## Decision (proposed)
Option 1.
- **Output contract**: per message, normalized content HTML + typed lists; legacy CSS class names that the stylesheet relies on (`citation`, `oldcitation`, `messCase2`, `signature`, `masque`, …) are part of the contract.
- **Sanitization contract**: `HFRParsing` is the sanitizer of record. Allow-list of tags and attributes; all event-handler attributes (`on*`) and `javascript:` URLs removed; every value the app injects (pseudo, date, labels) is escaped by the HTML builder.
- **Policy stays out**: blacklist, whitelist and filters are applied app-side on parsed messages.
- `MessageRenderOptions` is dropped from `HFRModels` unless a genuinely parse-time option appears.

## Consequences
- SwiftSoup stays confined; the riskiest transformations are Linux-testable against fixtures, independent of user settings.
- The app's HTML builder (Phase 4 backlog C12) applies image mode, embed mode, signature visibility from the typed lists without re-parsing.
- A sanitization test suite (malicious `onclick`, `javascript:` links, injected pseudos) is part of LOT-034.
