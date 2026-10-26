# LOT-025 — Small parsers (search redirect, profile edit page, smiley search and wiki)

- **Module:** HFRParsing
- **Difficulty / model:** easy (Sonnet → Opus)
- **Issue:** none (lot tracked in `docs/LOTS.md`)

First parsers tested on **real captured pages** (LOT-001 corpus). The oracle exporters (LOT-002..004) are not merged, so the
expected values come from what the captured HTML shows and from the legacy code (cited `file:line`).

## Legacy sources

Legacy repository <https://github.com/francoisgn/hfrnow> at `2440d79`. Audit: [B8](../audit/B-list-parsing-models.md), [D §3.1](../audit/D-posting.md), D9.

| Legacy | Replaced by |
|---|---|
| `Classes/ObjCForumSearchWorker.m:46-55, 305-321` (`forumSearchRedirectURLFromHTML:`: regex over `<meta … refresh …>`, `&amp;` → `&`, no match = "Aucune page de résultats") | `SearchRedirectParser.redirectURL(in:)` |
| `HFRswift/Swift/LoginService.swift:87-113` (`hash_check` regex, avatar regex on `profilCase3`) | `ProfileEditPageParser.parse(_:)` |
| `HFRswift/Swift/SmileySearchService.swift:62-88` (`<img>` regexes), `Classes/SmileyViewController.m:893-910` | `SmileySearchParser.parse(_:)` |
| `Classes/SmileyViewController.m:902-925` (`keywords0` split on spaces) | `SmileyWikiDetailParser.parse(_:)` |

## Behaviour

All functions are pure, `throws(ParsingError)`, go through `HTMLDocumentLoader` (`SwiftSoup.parseHTML`) and never expose SwiftSoup.

- **`SearchRedirectParser.redirectURL(in:) -> URL`** (capture `R50a`): first `<meta http-equiv="refresh">` (name and value compared
  case-insensitively) whose `content` is `<delay>;url=<target>` (`,` separator and quoted target accepted, as HTML does). The target is
  resolved with `HFRURL.absolute` (`&amp;` decoded, relative to the forum root). It must be `https`/`http` **on `forum.hardware.fr`**
  (the URL is requested with the search session): another scheme or host is `invalidValue`. No refresh meta with a target is
  `missingElement` (legacy: "no result page"). Models: returns a `URL`; B8's `Result<…, ListPageFailure>` is not used because the other
  parsers of this module throw `ParsingError` (the caller maps `missingElement` to the "no result page" message).
- **`ProfileEditPageParser.parse(_:) -> ProfileEditPage`** (`R55-p1`, `p3`, `p5`): `hashCheck` = first non-empty value of
  `input[name=hash_check]` (empty on all = `invalidValue`, none = `missingElement`); `avatarURL` = first `<img src>` in the `profilCase3` cell
  of the `tr.profil` whose `profilCase2` label starts with "Avatar", through `HFRURL.absolute`, else nil. Page 1 and 3 need no extra
  fields: they hold the same token, and the posts-per-page setting `topicpp` is LOT-044's.
- **`SmileySearchParser.parse(_:) -> [ForumSmiley]`** (`R53a-c`): every `<img>` whose `alt` is a smiley code (`[:…]`) and an `https`/`http` `src`, in served
  order, duplicates kept. The text "aucune réponse" without a smiley gives `[]`; neither gives `missingElement` (an error page must not look like "no match").
- **`SmileyWikiDetailParser.parse(_:) -> SmileyWikiDetail`** (`R54`): `code` = `input[name=smiley0]`, `keywords` = `input[name=keywords0]` split on
  whitespace, `imageURL` = the `<img>` next to `smiley0`. The contribution history lines (member, date, keywords) are not parsed.

## Edge cases

Redirect: other `<meta http-equiv>` first (Pragma, Cache-Control, Expires), `URL=` in upper case, refresh without target, `javascript:`, `//evil.example`,
`user@host` tricks, `http` upgrade. Avatar: image of another row must not be taken, `javascript:` source. Smileys: raw space/apostrophe in the path,
missing `alt`/`src`, relative `src`. Wiki: extra spaces, empty keywords, missing inputs.

## Fixtures

Shared corpus only, no new file: `R50a`, `R50c` (no refresh), `R53a` (40-byte text), `R53b` (657 smileys), `R53c` (1010, one repeated), `R54`,
`R55-p1`, `R55-p3`, `R55-p5`. Test helper `Tests/HFRParsingTests/Support/Fixture.swift` (also added identically by LOT-026).

## Not covered / gaps

- **AQ listing and RSS: not captured** (third-party host `aq.super-h.fr`, LOT-001 checklist row P08) and **left out**: no parser, no fixture.
- **No avatar capture**: the R55 captures were taken with `user2`, who has no avatar (the row offers "Créer un avatar" only). The avatar-present
  shape (`<img>` inside the cell) is **not verified**; the tests use a hand-written cell, named as such in the test.
- Smiley search with special characters, standard (non-personal) smileys and charset were not captured; all smileys of `R53b/c` are personal.
- Global search: only the waiting page and the results of a **no-result** search (`R50c`) exist; the POST answer for a search without any result is unknown.

## Intentional differences from legacy

- The redirect must be on the forum host; legacy followed any URL.
- The avatar is read from the "Avatar" row, not from the first `<img>` after any `profilCase3` (which would return an unrelated image on a page without an avatar).
- An answer with neither smiley nor "no result" text is an error, not an empty list.
- Keywords keep the characters served; legacy's comma removal was a no-op (result discarded, `SmileyViewController.m:919`).

## Learnings

- The anonymous and logged-in captures share a `hash_check` value shape (`REDACTED` here); parsers must not validate the token's format.
