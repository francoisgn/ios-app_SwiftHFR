# LOT-002 — Oracle exporter: legacy list parsers to JSON

- **Module:** tooling (legacy app)
- **Difficulty / model:** medium (Sonnet → Fable)
- **Issue:** none (lot tracked in `docs/LOTS.md`; audit item B10 in [B](../audit/B-list-parsing-models.md))

Harness, patch and run instructions: [`tooling/legacy-oracle/`](../../tooling/legacy-oracle/README.md).
This lot covers the **list** parsers. Topic pages are LOT-003; forms, write responses and storage formats are LOT-004.

## Legacy sources
Legacy repository <https://github.com/francoisgn/hfrnow>, commit `2440d79`. All line numbers are `Classes/`.

| Kind | Parser entry point (what the loader workers call) | Source |
|---|---|---|
| `forums` | `-[ObjCForumsParser parseForumsFromData:]` | `ObjCForumsParser.m` (whole file), called from `ObjCForumsLoaderWorker.m:28` |
| `topics` | `-[ObjCTopicListParser parseData:currentURL:]` | `ObjCTopicListParser.m:59-470`, called from `ObjCForumTopicsLoaderWorker.m:163` |
| `mp` | same parser; the URL is `/forum1.php?config=hfr.inc&cat=prive&page=1` | `ObjCMPTopicsLoaderWorker.m:9` |
| `search` | the same parser on the results page; redirect step in `-forumSearchRedirectURLFromHTML:` and URL helpers | `ObjCForumSearchWorker.m:47`, `:242-257` (results), `:259-275` (page info), `:304-342` (redirect and URLs) |
| `favorites` | `-[ObjCFavoritesLoaderWorker parseFavoritesFromData:]`, which drives `-[Favorite parseNode:]` and `-addTopicWithNode:` | `ObjCFavoritesLoaderWorker.m:79-168`, `Favorite.m:31-210` |

Helpers the parsers depend on: `Topic -setATitle:` applies `-filterTU` (`Topic.m:90`, `Helpers/RangeOfCharacters.m:330`);
`-decodeSpanUrlFromString2` decodes `md_cryptlink` classes (`Helpers/RangeOfCharacters.m:116`).

Not covered here, on purpose: `MPStorage.m:692` (`findStorageMPFromPage:` re-parses the MP list inline to find the storage topic; LOT-004),
`ObjCTopicSearchWorker` (search inside a topic; LOT-003).

## Behaviour
The exporter feeds the HTML bytes to the parser exactly as the workers do (raw `NSData`, no re-encoding) and serializes what the
legacy model objects hold. `oracle-map.json` in the input folder maps each file to a kind and an optional `currentURL`.
Defaults when `currentURL` is absent: `topics` and `search` use `/forum1.php?config=hfr.inc&cat=13&page=1`, `mp` uses the MP URL above;
`forums` and `favorites` take no URL. Page numbers in the output depend on `currentURL` (`ObjCTopicListParser.m:88-110`), so a real capture
must record the URL it was fetched from.

### JSON schema (`schema` 1)
Keys are sorted; `null` means "nil in legacy" and is kept because nil and `""` differ in legacy.

Envelope, every kind:

| Key | Content |
|---|---|
| `schema`, `case`, `kind` | `1`, file name without `.html`, kind |
| `legacyCommit` | `HFR_ORACLE_LEGACY_COMMIT` (the script passes `2440d79`) |
| `input` | `file`, `bytes`, `sha256`, `currentURL` (`null` for `forums` and `favorites`) |
| `exception` | `"Name: reason"` when the parser raised, else `null`. The raise is part of the oracle (see quirks) |
| `result` | per kind below; `null` when `exception` is set |
| `sideEffects` | see next section |

`result` per kind:

| Kind | `result` |
|---|---|
| `forums` | array of forums `{aTitle, aURL, aID, subCats}`; `subCats` is `null` or an array of the same shape. `aID` is `""` (never set by this parser) |
| `topics`, `mp` | list object, below |
| `search` | either `{page: "redirect", redirectURL, absoluteURL, relativeURL}`, or a list object plus `page: "results"` and `pageInfo` (the dictionary `-forumSearchPageInfoWithResultCount:` builds; keys with empty values are absent) |
| `favorites` | `{favorites: [{forum: {aTitle, aURL, aID, subCats}, order, topics: [topic]}], topicsSortedByLastPostDesc: [{catID, postID, aTitle}]}`. `favorites` is what the worker returns (visible categories, sorted by `order`) |

List object (`ObjCTopicListParsingResult`): `currentUrl`, `currentCat`, `forumNewTopicUrl`, `forumBaseURL`, `forumFavorisURL`,
`forumFlag1URL`, `forumFlag0URL`, `firstPageUrl`, `lastPageUrl`, `nextPageUrl`, `previousPageUrl`, `sNewMPNumber` (strings or `null`);
`pageNumber`, `firstPageNumber`, `lastPageNumber` (ints); `needToUpdateMP` (bool); `statusInfo` (`null`, or `{status, statusName, message}` with
`statusName` in `maintenance`, `noResults`, `noAuth`); `topics` (array).

Topic: strings `aTitle`, `aURL`, `aURLOfFirstPage`, `aURLOfFlag`, `aTypeOfFlag` (`""`, `red`, `blue`, `yellow`), `aURLOfLastPost`,
`aURLOfLastPage`, `aAuthorOfLastPost`, `aAuthorOrInter`, `sLastSearchPostContent`, `sLastSearchPostURL`; ints `aRepCount`, `maxTopicPage`,
`curTopicPage`, `postID`, `catID`; bools `isViewed`, `isViewedFromForumAtLoad`, `isLocallyViewedInApp`, `isPoll`, `isSticky`, `isClosed`,
`isSuperFavorite`; `dDateOfLastPost` (UTC ISO-8601 or `null`); `aDateOfLastPost` and `aDateOfLastPostKind` (`absolute` or `relative`).
Legacy writes `aDateOfLastPost` as "il y a 5 min" / "il y a 2 h" for recent posts and `dd/MM/yy` otherwise (`ObjCTopicListParser.m:426-447`),
so the relative forms change with the run date: they are exported as `null` with kind `relative`. Use `dDateOfLastPost` for comparisons.

### Side effects
Reset before every case, captured after it, in `sideEffects`:

| Key | Legacy write |
|---|---|
| `hashCheck` | `[HFRplusAppDelegate sharedAppDelegate].hash_check`: `ObjCForumsParser.m:42` (only when the `hash_check` input has a value), `ObjCFavoritesLoaderWorker.m:106` (always, `nil` when absent) |
| `nbMP` | `UserDefaults nb_mp`, set by `-updateMPBadgeWithString:` (`HFRplusAppDelegate.m:702`): from the home page `cat=prive` row (`ObjCForumsParser.m:516-525`) and the favorites page MP block (`ObjCFavoritesLoaderWorker.m:97-103`). `null` = never called. The topic list parser does not write it; it only reports `needToUpdateMP` / `sNewMPNumber` |
| `arrayCategoriesVisibleOrder`, `arrayCategoriesHiddenOrder` | `UserDefaults`, read as input and written back by the favorites parser (`ObjCFavoritesLoaderWorker.m:36-37,157-158`). Reset to empty, so a run behaves like a first launch (`order` follows page order) |
| `statusNotifications` | `kStatusChangedNotification` posted by the forums parser on a maintenance page (`ObjCForumsParser.m:20-26`) |

The SwiftUI app delegate adaptor is not an `HFRplusAppDelegate`, and `+sharedAppDelegate` is a bare cast (`HFRplusAppDelegate.m:430`), so the
exporter installs a real `HFRplusAppDelegate` as `UIApplication.delegate` for the run and restores the previous one.
`recherche_categorie` (`ObjCForumSearchWorker.m:28`) is written by the search entry, not by the parsing we export; the exporter saves and restores it.

## Edge cases
Legacy quirks observed on the synthetic samples (each is a sample file; `Q` numbers are for the review of the Swift port):

- Q1 `topics-page2`, `topics-page-last-spans`: the pager reads `.left` children by index, **text nodes included** (`ObjCTopicListParser.m:172-252`, children read at `:180-181,201`).
  Child 2 is the first page, the last child is the last page. A page that is the current one gets `currentUrl` as its URL
  (`lastPageUrl == currentUrl` on the last page).
- Q2 `topics-broken-pager`: fewer than 3 children raises `NSRangeException` (`exception` set, no result). In the app this is uncaught.
- Q3 `topics-single-page.html` with `currentURL=/forum-nodigit.php` (ad hoc run, not a sample): a `currentURL` without `page=` and without a digit
  raises `NSInvalidArgumentException` at `ObjCTopicListParser.m:102-103` (`substringWithRange` on `NSNotFound`; `Favorite.m:191-192` has the same pattern).
- Q4 `topics-bad-date`: an unparseable last-post date gives `dDateOfLastPost: null` and a **relative** display string, not an error
  (`timeIntervalSinceDate:nil`, `ObjCTopicListParser.m:421-447`).
- Q5 Pages without a charset declaration are decoded as Latin-1 by the HTML parser, which breaks `à` in the date format and so triggers Q4.
  The samples declare UTF-8. Real captures must be checked for the charset the live site sends.
- Q6 `Topic -setATitle:` rewrites "topic unique" (and 8 other spellings, case-insensitive) to `TU` before storing the title (`topics-page2`, row 102).
- Q7 Poll detection uses two different image URLs: `.../images/defaut/sondage.gif` in the topic list (`ObjCTopicListParser.m:331`) but
  `.../images_forum/1/sondage.gif` in favorites (`Favorite.m:70`, the comment above it shows the first URL). `favorites-multi-cat`, rows 402 and 403.
- Q8 Unread is `alt="On"` in `sujetCase1`; no image means read (`ObjCTopicListParser.m:378-390`). `isViewed` is also `true` for favorites rows without a flag link.
- Q9 `curTopicPage` is `0` when the row has no flag link; with a flag it is the `page` of the flag URL (`HFRTopicPageNumberFromURLString`, `:9-38`).
  Favorites compute it differently (`Favorite.m:182-199`, last digit of the URL when `page=` is absent).
- Q10 Early returns: a body without `id` gives `noAuth` (or `maintenance` when the first child is `<p>`) with most fields at their defaults
  (`forumBaseURL: null`, `forumNewTopicUrl: ""`, `currentCat: ""`); no rows gives `noResults` ("Aucun message") after the pager and filter fields are read.
  Favorites turns the same cases into a thrown `FavoritesLoadError` (`ObjCFavoritesLoaderWorker.m:87-95`).
- Q11 Home page: the `Apple` row is dropped unless `hash_check` has a value (`ObjCForumsParser.m:77-80`); the `cat=prive` row is not a forum, it only
  updates the MP badge; `AchatsVentes/Hardware` is rewritten (`:69`); `subCats[0]` repeats the parent; about 30 sub-forums are injected by URL
  (`:84-500`, samples: PHP gives Python and Ruby/Rails, minipc gives Bench). `aID` stays `""`.
- Q12 `subCats` is never `nil` in the export: forums without a `Tableau` link and the sub-forums themselves carry `[]` (the model initializes it), so `[]` does not mean "no sub-forums parsed".
- Q13 `forums-maintenance`: returns `[]` and posts a notification; a maintenance page is not an error for the parser.

Not exercised by the synthetic samples, to cover with real captures: the exact markup of the pager (Q1 assumes the shape described by
[HFR-PROTOCOL](../HFR-PROTOCOL.md) §7 row E7), `md_noclass_cryptlink`, `md_blank_cryptlink` variants, titles with entities and `&nbsp;`,
pseudo with special characters, anonymous last author (`<b>` missing), `sujetCase3` with a second link on non-search pages, replies counts with separators.

## Fixtures
Synthetic, in `tooling/legacy-oracle/samples/` (fake pseudos `fakeuser1`..`fakeuser3`, fake hash `FAKEHASH0123456789`, no real data):

| File | Kind | Covers |
|---|---|---|
| `forums-loggedout`, `forums-loggedin`, `forums-maintenance` | forums | Apple censoring, MP row and badge, hash_check, sub-forum injection, URL rewrite, maintenance notification |
| `topics-page2`, `topics-page-last-spans`, `topics-single-page`, `topics-empty` | topics | pager with links and with `md_cryptlink` spans, sticky, closed, unread, poll, three flag colors, 12-page topic, 1234 replies, future date, TU rewrite, no pager, no rows |
| `topics-noauth`, `topics-maintenance`, `topics-broken-pager`, `topics-bad-date` | topics | status paths, raised exception (Q2), unparseable date (Q4) |
| `mp-list` | mp | MP block (`needToUpdateMP`, `sNewMPNumber`), `[non lu]`, multi-interlocutor author |
| `search-redirect`, `search-results` | search | meta refresh extraction and URL helpers; snippet (`s1`) and second link |
| `favorites-multi-cat`, `favorites-empty`, `favorites-noauth` | favorites | categories and order, flag link or not, polls (Q7), sticky, closed, empty category, thrown error |

Real captures arrive from LOT-001 into `Packages/HFRKit/Tests/HFRParsingTests/Fixtures/captures/`; run the script on that folder with an `oracle-map.json`
and commit the `.oracle.json` beside each page.

## Intentional differences from legacy
Not applicable: this lot exports legacy behaviour as it is. The Swift port documents its own differences against the quirks above (B §5 decisions:
no side effects, typed errors instead of `statusInfo` and exceptions, no display strings).
The exporter itself departs from legacy output in three places, all to make the files reproducible: relative date strings are dropped (see schema),
dates are ISO-8601 UTC, and the app delegate is replaced by a real `HFRplusAppDelegate` for the run.

## Learnings
To copy into AGENTS.md §11 when the lot closes:

- Xcode 27 cannot build Carthage dependencies with their own settings: pass `tooling/legacy-oracle/carthage-xcode27.xcconfig` through `XCODE_XCCONFIG_FILE`.
- `xcodebuild` forwards environment variables to the simulator test process only with the `TEST_RUNNER_` prefix.
- Legacy parsers raise `NSException` on malformed pages; Swift cannot catch it, so the oracle goes through an Objective-C `@try` helper and records the raise as data.
- HTML pages given to the legacy parser need a charset declaration, or accented characters are read as Latin-1 (Q5).
