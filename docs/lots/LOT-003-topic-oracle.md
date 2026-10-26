# LOT-003 — Oracle exporter: legacy topic-page pipeline to JSON

- **Module:** tooling (legacy app)
- **Difficulty / model:** medium (Opus → Fable)
- **Issue:** none (lot tracked in `docs/LOTS.md`; audit item C00 in [C](../audit/C-message-parsing.md))

Harness, patch and run instructions: [`tooling/legacy-oracle/`](../../tooling/legacy-oracle/README.md) (shared with [LOT-002](LOT-002-list-oracle.md)).
This lot adds the kind `topic`: one topic page through the whole live pipeline, from the response bytes to the HTML the
`WKWebView` loads, plus the per-message actions Swift reads. Forms, write responses and storage formats are LOT-004.

## Legacy sources
Legacy repository <https://github.com/francoisgn/hfrnow>, commit `2440d79`. Paths from the repository root.

| Step | Legacy code the exporter runs | Source |
|---|---|---|
| Response bytes | `-[ASIHTTPRequest safeResponseData]` (iconv drops invalid UTF-8) | `SuperHFRplus/Helpers/ASIHTTPRequest+Tools.m:14-38`, called at `Classes/ObjCTopicPageWorker.m:95` |
| Request setup | properties set by `-fetchContentForTopicURL:anchor:completion:` (`completion`, `currentURL`, `anchor`, `separatorRequested`) | `Classes/ObjCTopicPageWorker.m:78-101` |
| Whole page | `-[ObjCTopicPageWorker handleResponseData:effectiveURL:]` | `Classes/ObjCTopicPageWorker.m:103-146` |
| Messages | `-[ParseMessagesOperation parseData:]` (normal mode) → `LinkItem` | `HFRswift/Wrapped/ParseMessagesOperation.m:107-557` |
| Page metadata | `-parseMetadataFromBody:parser:` (`hop` hidden fields, `repondre_form`, `nonlu`, `sondage`), `-searchInputDataFromBody:` (`transsearch.php` form) | `Classes/ObjCTopicPageWorker.m:148-179` |
| Current page | `HFRTopicPageWorkerPageNumberFromURLString` on the effective URL | `Classes/ObjCTopicPageWorker.m:14-43,119,181-185` |
| Message HTML | `-[ObjCTopicMessageContentBuilder buildContentForItems:…]` → `-[LinkItem toHTML:isMP:]` per message | `Classes/ObjCTopicMessageContentBuilder.m:8-48`, `HFRswift/Wrapped/LinkItem.m:23-303`, template `SuperHFRplus/Assets/HTML/templatev2.htm` |
| Page shell | `-[ObjCTopicHTMLRenderer renderHTMLWithContext:]` | `Classes/ObjCTopicHTMLRenderer.m:9-105` |
| Actions | `-swiftMessageActionsByIndex` → `-[ObjCMessageActionsBuilder actionsByIndexForItems:…]` | `Classes/ObjCTopicPageWorker.m:193-199`, `Classes/ObjCMessageActionsBuilder.m:9-103` |
| Poll | Swift `PollHTMLParser.parse(from:)` on `swiftPollHTML`, as `ObjCTopicPageLoader` does | `HFRswift/Swift/PollData.swift:107-355`, `HFRswift/Swift/Common.swift:1800-1836` |
| Obfuscated links | `-[NSString decodeSpanUrlFromString]` | `SuperHFRplus/Helpers/RangeOfCharacters.m:92-114` |
| Filter mode (optional) | `-parseData:filterPostsQuotes:YES startAfterThisPostId:topicUrl:topicPage:` as `FilterPostsQuotes` calls it | `Classes/FilterPostsQuotes.m:279-283`, `ParseMessagesOperation.m:141-144,228-237,319-361` |

The "display HTML" oracle (C00) is the output of `ObjCTopicHTMLRenderer`, the string `ObjCTopicPageWorker` hands to its completion and
that Swift writes to `Caches/cache/topic-<UUID>.htm` (`Common.swift:1962-1972`). Swift later injects theme variables, message style and
text size by JavaScript (`MessagesView.swift:1289-1470`); that part is not in the oracle.

Not covered, on purpose:

- `ObjCTopicSearchWorker` (`Classes/ObjCTopicSearchWorker.m:9-67`) parses no HTML: it posts the search form and returns the `Location`
  header. Its result page is an ordinary topic page, covered by the `topic` kind. There is no `topicsearch` kind.
- `ObjCFilteredPostsRendererWorker` (rendering of filtered posts) and its `Topic` input; filter mode exports the parsed messages and
  their `toHTML` only.
- The topic flag state (`delflag`, `flagn0.gif`) is not read by the live pipeline (only the legacy-only `MessagesTableViewController`
  did, C §1.2); the only flag-related output is `unreadable` (`href` containing `nonlu`).
- Swift's `TopicPageMessageActions` decoding (`Common.swift:1838-1900`): the oracle stops at the dictionaries it decodes.

## Behaviour

### Inputs
`oracle-map.json` entry for a page, all keys but `kind` optional:

| Key | Use | Default |
|---|---|---|
| `kind` | `"topic"` | |
| `currentURL` | relative URL the page was fetched from (after redirects); drives `currentPage` and permalinks | `/forum2.php?config=hfr.inc&cat=13&post=1000&page=1` |
| `anchor` | fragment of the request (`#t<post>`); non-empty means "flag" mode: separator and resolved anchor | `""` |
| `ownPseudo` | pseudo of the main account (`MultisManager getMainCompte`); absent or `null` = no account | none |
| `blacklist`, `whitelist` | pseudos; the blacklist belongs to `ownPseudo` (`BlackList.m:92-99`), so it is ignored without one | `[]` |
| `settings` | `UserDefaults` overrides of the fixed set below | `{}` |
| `avatarFetch` | `succeed` (the download completes), `fail`, `blocked` (never completes) | `succeed` |
| `filter` | `{startAfterPostId, topicUrl, topicPage}`: also run the parser in filter mode | none |

A real capture must record the URL it was fetched from and the account it was fetched with.

### Fixed settings
Applied before every topic case (all other keys are left as they are), restored after the run:

| Key | Value | Why |
|---|---|---|
| `display_images` | `yes` | forced at every launch (`HFRplusAppDelegate.m:115-116`) |
| `filter_posts_quotes`, `filter_posts_min_quotes` | `wl_pseudo`, `3` | launch defaults (`HFRplusAppDelegate.m:108-114`) |
| `theme_noel_disabled` | `true` | forced at launch (`HFRplusAppDelegate.m:100`) |
| `display_sig`, `embedded_videos`, `blacklist_hide_pseudo`, `theme_style`, `mpstorage_active` | `no`, `yes`, `false`, `1`, `false` | `InAppSettings.bundle/Root.inApp.plist` defaults, registered at launch (`HFRplusAppDelegate.m:394-426`) |
| `auto_theme`, `theme` | `0`, `0` | manual light theme (`Common.swift:268-273,304-308`) |
| `force_manual_theme`, `theme_{day,night}_color_{action,love,superfavori}`, `theme_night_brightness` | removed | default colors |

### Run
Per case: settings applied; `BlackList.shared` lists replaced in memory (never saved); the avatar cache `Caches/cache/avatars` emptied
(every case behaves like a first launch, so the 24 h refresh rule of `ParseMessagesOperation.m:431-450` is not exercised); two runtime
hooks installed for the case only: `-[MultisManager getMainCompte]`/`-getCurrentPseudo` return `ownPseudo`, and `-[ASIHTTPRequest start]`
records the URL and, depending on `avatarFetch`, runs the request's completion block, its failure block or nothing, without any network.
Then: `safeResponseData` on the file bytes, the worker's properties set as `fetchContentForTopicURL:` does, `handleResponseData:` with
`effectiveURL = https://forum.hardware.fr<currentURL>`, the main run loop spun until the worker's completion fires (10 s limit). The
exporter then reads the worker, calls `toHTML:isMP:` on each item (same arguments as the builder), the content builder once more for
`resolvedAnchor`, and parses the page a second time with `ParseMessagesOperation` alone to get what the worker drops (`iLastPageNumber`).
Exceptions are data (`exception`, `htmlException`, `{exception}` values) through `OracleObjCSafe`.

### JSON schema (`schema` 1, kind `topic`)
Envelope as in LOT-002, plus `input.context` (the effective inputs: `ownPseudo`, `blacklist`, `whitelist`, `anchor`, `avatarFetch`,
`settings`, `filter`). `null` = nil in legacy. Absolute paths under the app's caches directory are written `$CACHES` (the simulator
container changes per install).

`result.page`:

| Key | Content |
|---|---|
| `topicName`, `sNavigationViewTitle` | worker `_topicName` (= parser `topicName` or `""`) and the navigation title Swift reads |
| `currentURL` | worker `currentURL` after `relativeURLFromOriginalURL` (`ObjCTopicPageWorker.m:187-191`) |
| `currentPage`, `maxPage`, `answerURL` | the completion's values: page from the URL, `MAX(iLastPageNumber, 1)`, absolute answer URL or `null` |
| `topicAnswerURL` | raw `href` of the first `a` in `#repondre_form` |
| `inputData` | hidden inputs of `form[name=hop]` (contains `hash_check`) |
| `unreadable` | an `href` contains `nonlu` (sets `canBeFavorite`) |
| `searchInputData` | kept inputs of the `transsearch.php` form |
| `poll` | `{hasPoll, isNewVote, html, parsed}`: `.sondage` raw HTML and `PollHTMLParser` output (`question, footer, maxChoices, isVotable, options[{id,text,fieldName}], results[{id,label,percentage,voteCount}], hiddenFields}`) |
| `completionError` | `"<domain> <code>"` if the worker failed, else `null` |

`result.parser`: `iLastPageNumber`, `iFirstPageNumber` (never set: always 0), `topicName` (raw, `null` if none), `itemCount`.

`result.messages[]` (one per `LinkItem`, in order; `index` = DOM id `%%ID%%`): strings `postID` (with the `t`), `name`, `messageDate`,
`dicoHTML` (libxml2 serialization of the `para` node), `imageUI`, `urlQuote`, `urlEdit` (the obfuscated `class` values), `urlProfil`,
`urlAlert`, `addFlagUrl`, `quoteJS`, `MPUrl`, `quotedNB`, `quotedLINK`, `editedTime`, `url`; `isDel`; `iPage`; `urlQuoteDecoded` /
`urlEditDecoded` (raw `decodeSpanUrlFromString`, or `{exception}`); `html` (`toHTML:isMP:`) and `htmlException`.
`LinkItem` properties the parser never sets (`flagUrl`, `typeFlag`, `lastPostUrl`, `lastPageUrl`, `viewed`, `rep`, `messageAuteur`, `isBL`;
C §1.3) are not exported.

`result.actions[]`: the dictionaries of `swiftMessageActionsByIndex`, sorted by `index` (added key). Values are strings, flags `"0"`/`"1"`,
keys with empty values absent (`ObjCMessageActionsBuilder.m:64-68`). `{exception}` if the call raised.

`result.render`:

| Key | Content |
|---|---|
| `pageHTML` | the renderer output. When the messages part occurs exactly once in it, it is replaced by `<!--ORACLE:messagesHTML-->` (`pageHTMLTokenized: true`): it is the concatenation of `messages[].html` |
| `separatorAfterIndex` | index after which `<div class="separator1"></div>` was inserted, or `null` |
| `messagesHTMLIfNotRebuildable` | the builder output when it is not `messages[].html` plus the separator (never seen), else `null` |
| `resolvedAnchor`, `workerAnchorAfter` | the builder's `resolvedAnchor` and the worker `anchor` after the run (same value; unused by Swift, C §1.3) |
| `builderException` | the builder call raised |

`result.filterMode` (only with `filter`): `{messages: [...]}` (same shape; `toHTML` with `isMP: YES` as `ObjCFilteredPostsRendererWorker`
does) or `{exception}`.

### Side effects
Keys of LOT-002 (`hashCheck`, `nbMP`, category orders, `statusNotifications`; all untouched by the topic pipeline in every sample), plus:

| Key | Content |
|---|---|
| `networkRequests` | URLs the pipeline tried to fetch (avatars, in message order, one per message with an avatar, duplicates kept) |
| `filterNetworkRequests` | the same for the filter-mode parse |
| `defaultsWritten` | `UserDefaults` keys whose value changed during the pipeline, with the new value. Every case shows `theme_day_color_action` and `theme_day_color_love`: `ThemeColors` stores its default colors the first time they are read |
| `safeResponseDataChangedBytes` | `true` when iconv dropped invalid bytes |

## Edge cases
Quirks observed by running the samples (`Q` numbers continue LOT-002's list; S = synthetic sample, R = LOT-001 capture, run but not committed here):

- Q14 The renderer replaces `iosversion` everywhere, message text included (`ObjCTopicHTMLRenderer.m:104`): `topic-anonymous` message 3 keeps
  "iosversion" in `messages[2].html` but shows "ios7" in the page, so `pageHTML` is not tokenized there.
- Q15 `toHTML` substitutes `%%ID%%` inside message text (`LinkItem.m:274-276`, "séparateur%%ID%%" → "séparateur2") and deletes every
  `---------------` (`:74`) and every `\n` (`:39,279`).
- Q16 `Publicité` blocks are skipped (`ParseMessagesOperation.m:172-174`); real pages carry 3 per page (R20, R22a, R26), so 43 `messagetable`
  give 40 messages.
- Q17 Page 2+ starts with the "Reprise du message précédent" block, a copy of the previous page's last post with the same `postID`
  (`topic-loggedin`, R22a, R22b, R26, R27, R28). Normal mode keeps it as message 0, so it is never deletable (`canDelete` needs `index > 0`).
- Q18 `currentPage` comes from the URL only: R24 (requested page 2202 of 2201, served as the last page) gives `currentPage: 2202`, `maxPage: 2201`.
- Q19 Single-page topics have no `.left` in `fondForum2PagesHaut`: `iLastPageNumber 0`, `maxPage 1` (`topic-content`, R23, R27b, R31). On the last
  page the last child is `<b>N</b>`, read the same way (`topic-poll-results`, R22b).
- Q20 Own-pseudo checks only lowercase (`ParseMessagesOperation.m:183-184`, `LinkItem.m:47`): `fake​user1` (with U+200B) is not "me" while
  blacklist and whitelist matching strip U+200B (`BlackList.m:133-135`). Real pseudos do contain U+200B (R21 message 1).
- Q21 Class priority in `toHTML`: `del` is added first, then only one of `mode` / `me` / `whitelist` / `bl` (`LinkItem.m:41-54`): a deleted
  whitelisted message is `message whitelist del`. A blacklisted author gets `class="header bl""` (stray quote, `:53`).
- Q22 Quote classes follow the quoted author (`.Topic` text minus 10 characters): own → `citation_me_quoted`, whitelisted (case-insensitive)
  → `citation_whitelist`, blacklisted → `citation_blacklist` + show/hide tables with ids `1<id>`, `<id>`, `3<id>` (`3<id>` never exists).
  `oldcitation` is renamed `citation` first. Nested quotes are handled at every depth (`topic-content` message 0).
- Q23 Standard smileys are rewritten to local files only for `http://forum-images…` (`LinkItem.m:139-141`); real pages use `https://`
  (R20, R21, R27), so no smiley is rewritten on real pages (0 on all 13 captures). Custom `images/perso/` smileys are rewritten, `'` escaped.
- Q24 With `display_images: yes`, a bare image is wrapped into a link to itself and both shapes get `class="hfrplusimg" title="<index>"`
  (`LinkItem.m:182-190`); `hfr-rehost.net` becomes `reho.st` (`:163`). Images without `onload`/`style` attributes are left untouched.
- Q25 Video embedding (`ParseMessagesOperation.m:238-317`): `t=1h2m3s` gives `start=7323` (hour bug, `:281`); `youtu.be/…?t=90` gets no start;
  a link whose text holds markup keeps `class="embedvideo"` with `hrefemb`/`hreftxt` but no iframe (`LinkItem.m:149`); links in a signature are
  not embedded. `embedded_videos: both` adds the original link under the iframe.
- Q26 Signature (`display_sig: no`): everything from `<span class="signature">` is cut and `</div>` appended (`LinkItem.m:236-246`), the
  `nosig` class is put on the container. HFR puts `.edited` before the signature (R21, R27), so it survives; `editedTime`/`quotedNB` are
  appended after the content anyway (`:249-254`).
- Q27 An obfuscated value of odd length raises `NSInvalidArgumentException` in `decodeSpanUrlFromString` (`RangeOfCharacters.m:106-107`);
  the actions builder catches it and absolutizes the raw class: `quoteURL: https://forum.hardware.fr/md_noclass_cryptlink…` (`topic-content`
  message 6, `ObjCMessageActionsBuilder.m:84-88`).
- Q28 `editedTime` keeps the decoded `&nbsp;` (U+00A0) around "à" (`"fakeuser4 le 03-02-2026 à 10:00:00"`).
- Q29 `isOwnMessage`/`canDelete` follow the presence of the edit link only; in an MP (`cat=prive`) `canAQ` is `0` and `isPrivateCategory` `1`.
  `canBookmark` is `0` everywhere because `mpstorage_active` is `false`.
- Q30 Anonymous poll pages carry the voting form (R32a): `isNewVote: true` and `parsed.isVotable: true` without an account. Poll option labels
  keep entities (`"Oui &amp; non"`, `PollData.swift:224`).
- Q31 Filter mode drops message 0 of each page, keeps own posts, whitelisted authors (`wl` in `filter_posts_quotes`), posts quoting the own
  pseudo, posts whose HTML contains the own pseudo (`pseudo` mode, so "Message édité par fakeuser1" is enough), and posts quoted ≥ 3 times
  (`topic-content`: 2004 to 2007 kept). `url` = `https://forum.hardware.fr` + `topicUrl` with `#t…` replaced by the post id.
- Q32 The serialization differs from the page bytes (C §3, quirk 1): `<br />` → `<br>`, a newline after the opening `para` tag in `dicoHTML`,
  attributes kept in source order; `toHTML` regexes depend on it.

Observed on the 13 LOT-001 topic captures (anonymized, not committed by this lot), for the specs of LOT-030 and following:
no page has an `avatar_center` block (so no avatar request and no `imageUI`), every message has an obfuscated `md_noclass_cryptlink`
quote link, anonymous pages have no `quoteJS`, MP, favorite or alert links, `hop`/`repondre_form` exist only logged in, the locked topic
(R31) and anonymous pages give `answerURL: null`, and iconv never changed the bytes.

Not exercised, to cover with real captures: own messages with an edit link (`alt="edit"`), deleted messages (`messagetabledel`), moderation
messages, avatars, a poll with results, `nonlu`, in-topic search results (the `messCase2` leading `<a>`, `ParseMessagesOperation.m:365-368`),
a page where the "new messages" separator follows a real flag.

## Fixtures
Synthetic, in `tooling/legacy-oracle/samples/` (fake pseudos `fakeuser1`..`fakeuser4`, fake hash `FAKEHASH0123456789`, crypt links
encoded with the alphabet above, no real data). Markup follows the shapes of real pages; the poll results block follows the Swift
parser (`PollData.swift:270-355`) because no capture shows one yet.

| File | Context | Covers |
|---|---|---|
| `topic-anonymous` | no account, page 1/3 | avatar, ad block, smileys (http, https, perso), bare and linked images, rehost, internal links, `iosversion`, `%%ID%%`, `---------------` |
| `topic-loggedin` | `fakeuser1`, pretty URL page 2/3, anchor `#t1004` | "reprise" block, own messages with edit links, `quoteJS`/MP/flag/alert, `hop`, `repondre_form`, search form, separator |
| `topic-content` | `fakeuser1`, BL `fakeuser3`, WL `fakeuser2`, filter mode | nested/old/own/BL/WL quotes, BL author, Modération, spoiler, code, videos, signature, edited and quoted counts, deleted, U+200B pseudo, broken crypt |
| `topic-content-variants` | same page, `display_sig: yes`, `embedded_videos: both`, `blacklist_hide_pseudo: true`, avatars `fail` | settings variants |
| `topic-poll-vote` | `fakeuser1`, single page | multi-choice poll with inputs |
| `topic-poll-results` | no account, last page 4/4, avatars `blocked` | poll results and footer, last-page pager |
| `topic-mp` | `fakeuser1`, `cat=prive` | private-category actions |
| `topic-empty` | no account | page without messages |

Real captures arrive from LOT-001 into `Packages/HFRKit/Tests/HFRParsingTests/Fixtures/captures/`; their map entry needs the fetch URL
(`currentURL`) and, for logged-in pages, the anonymized pseudo of the account (`ownPseudo`).

## Intentional differences from legacy
Not applicable: the exporter records legacy behaviour. Its departures, all for reproducibility: no network (avatars per `avatarFetch`),
account list and blacklist from the case instead of the keychain and `Documents`, empty avatar cache per case, `$CACHES` for the container
path, the messages part of the page HTML replaced by a token when it can be rebuilt from `messages[].html`.

## Learnings
To copy into AGENTS.md §11 when the lot closes:

- The topic pipeline is reachable offline by calling `-[ObjCTopicPageWorker handleResponseData:effectiveURL:]` on saved bytes; its completion
  is dispatched to the main queue, so the exporter spins the main run loop.
- `ParseMessagesOperation` downloads avatars with ASIHTTPRequest; an offline oracle must replace `-[ASIHTTPRequest start]` (it is a
  concurrent operation: finish it with `markAsFinished`), not `URLProtocol`, which ASIHTTPRequest does not use.
- Settings are read with `stringForKey:`/`boolForKey:` at parse and render time: an oracle without a fixed settings set depends on the
  simulator's history.
