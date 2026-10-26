# Capture corpus (LOT-001)

Shared corpus of live HFR responses captured on 2026-10-26 with `tooling/fixtures/flows.py`, then anonymized with
`tooling/fixtures/anonymize.py` (pseudos → `user1`/`user2`/`userN`, operator ids → `9000NN`, other members' profile
ids → `9100NN`, tokens and cookies → `REDACTED`). Each capture has `<id>.meta.json`: URL template, requested and final
URL, redirect hops, HTTP status, content type, server date, account role (`anon`, `user1`, `user2`), names of the
cookies set (never values) and, for POSTs, the anonymized request body in field order.
Per-lot oracles (legacy parser output) are added next to these files by LOT-002..004.

Checklist: LOT-001 capture checklist (operator-approved 2026-10-26). Ids follow its rows; a suffix (`a`, `b`, `-1`)
splits a row into several captures. Public topics were picked from the anonymous lists R04-R07 (neutral subjects).

**Run status: partial.** Only read-only rows ran. Every `user1` login was refused (W01), so the write flows (W10-W20,
P03) and the rows that need both accounts were not captured; "logged in" rows below ran as `user2`. The run stopped at
the first HTTP 500 (R55 path check, see notes). Requests: 52 of the 120 budget.

| Id | File | Covers | Row | Lots |
|---|---|---|---|---|
| R01 | `R01-home-anon.html` | Home, logged out: 19 categories (incl. `apple`, `ia`), moderator MP links, empty `hash_check` in `#fastsearch` | R01 | 021, 045 |
| R03 | `R03-home-logged-in-no-unread-mp.html` | Home, logged in (user2), no unread MP: MP row "Envoyer / lire des messages privés" without a count; 32-hex `hash_check` | R03 (R02, unread = 1, not captured) | 021, 023, 047 |
| R04 | `R04-list-cat13-p1-anon.html` | Topic list cat 13 page 1 via `forum1.php` → 301 to `/hfr/Discussions/liste_sujet-1.htm`: sticky, locked, poll rows, big page counts | R04 | 022, 002 |
| R05a | `R05a-list-cat13-p12-anon.html` | List page 12: pager links obfuscated (`md_cryptlink`) except page 1 | R05 | 022 |
| R05b | `R05b-list-cat13-p500-anon.html` | Deep list page 500 (not the last page: the pager goes on) | R05 | 022 |
| R06 | `R06-list-subcat-cuisine-anon.html` | Sub-forum list `/hfr/Discussions/Cuisine/liste_sujet-1.htm` | R06 | 022 |
| R07 | `R07-list-graphisme-anon.html` | Another forum's list page 1 (`/hfr/Graphisme/…`) | R07 | 021, 022 |
| R08-1 | `R08-1-list-cat13-owntopic1-empty.html` | `owntopic=1`, logged in, empty: `.hop` "Aucun sujet auquel vous avez participé n'est connu" | R08 | 022, 024 |
| R08-2 | `R08-2-list-cat13-owntopic2.html` | `owntopic=2` (read), one row: the topic read by R21 (E25), `flag0`/`flag1`/`favoris` icons | R08, R15/R58 | 022, 024, 045 |
| R08-3 | `R08-3-list-cat13-owntopic3-empty.html` | `owntopic=3`, empty: "Aucun favori n'est repertorié" | R08 | 022, 024 |
| R09 | `R09-list-cat13-owntopic3-anon.html` | `owntopic=3` logged out: 301 to the plain list, filter silently dropped | R09 | 022, 037 |
| R10 | `R10-favourites-owntopic1.html` | `forum1f.php?owntopic=1`, two tracked topics in two categories | R10 | 024 |
| R11 | `R11-favourites-owntopic3-empty.html` | `forum1f.php?owntopic=3` with no favourite | R11 | 024 |
| R12 | `R12-favourites-anon.html` | `forum1f.php` logged out: `<body>` without `id`, `.hop` "Aucun sujet que vous avez lu n'est connu" | R12 | 024, 037 |
| R20 | `R20-topic-p1-anon.html` | Topic page 1, 40 posts, logged out: action links `message.php?…&numrep=N&ref=M…#formulaire` in `md_noclass_cryptlink` spans, ads | R20 | 030-033, 003 |
| R21 | `R21-topic-p1-logged-in.html` | Same page logged in: same action-link shape, `quoter(…)` JS, `addflag`/`delflag`/`modo.php` links, `#repondre_form`, fast-answer `hop` form, logout link (token redacted) | R21 | 030, 031, 033 |
| R22a | `R22a-topic-middle-page-anon.html` | Middle page (1100): "reprise du message précédent" block, 33 bodies | R22 | 030, 033 |
| R22b | `R22b-topic-last-page-anon.html` | Last page (2201), 10 posts | R22 | 030, 033 |
| R23 | `R23-topic-single-page-anon.html` | Single-page topic | R23 | 033 |
| R24 | `R24-topic-beyond-last-page-anon.html` | `page=max+1`: 301, 301, then 302 to the last page | R24 | 045, 033 |
| R25 | (meta only) | Permalink `…&numreponse=M`: 301 with relative `Location: …-sujet_<post>_<page>.htm#t<M>`, empty body | R25 | 045 |
| R26 | `R26-topic-quotes-smileys-anon.html` | Chatty page: quotes, many personal smileys, signatures | R26, R30 | 032, 034 |
| R27 | `R27-topic-spoilers-anon.html` | Spoilers, quotes, YouTube embeds, edited/cited trailers | R27 | 034 |
| R27b | `R27b-topic-code-blocks-anon.html` | Code blocks (cat 10, single page) | R27 | 034 |
| R27-list | `R27-list-list-programmation-anon.html` | Programmation list page 1 (used to pick R27b) | — | 022 |
| R28 | `R28-topic-images-videos-anon.html` | 42 images, quotes, spoiler, YouTube | R28, R29 | 034, 035, 056 |
| R31 | `R31-topic-locked-anon.html` | Locked, sticky, single-page topic | R31 | 033, 036 |
| R32a | `R32a-topic-poll-anon.html` | Poll topic logged out: vote form `/user/vote.php?config=hfr.inc` shown, radio `reponse` | R32 | 026, 054 |
| R32b | `R32b-topic-poll-logged-in-not-voted.html` | Same, logged in, not voted | R32 | 026, 054 |
| R40a | `R40a-reply-form-logged-in.html` | Reply composer (`message.php`), logged in: `hop` form to `/bddpost.php?config=hfr.inc`, `verifrequet=1100`, pseudo echoed, checkboxes | R40 | 036, 048 |
| R40b | `R40b-reply-form-anon.html` | Same composer logged out: empty `hash_check`, visible pseudo/password | R40 | 036, 048 |
| R41a | `R41a-quote-form.html` | Quote form (`numrep=<cited>&ref=1`): prefill `[quotemsg=<numreponse>,1,<author id>]` | R41 | 036, 049 |
| R41b | `R41b-quote-form-of-quoting-post.html` | Quote of a post that quotes (`ref=3`): second value 3 | R41 | 036, 049 |
| R42 | `R42-multiquote-form-cookie.html` | Composer with cookie `quoteshardwarefr-13-<post>=\|a\|b`: two `[quotemsg]` blocks prefilled | R42 | 049 |
| R45a | `R45a-new-topic-form.html` | New-topic form `/hfr/Discussions/nouveau_sujet.htm`: `sujet`, `toread1..5`, `subcat` select | R45 | 036, 048 |
| R45b | `R45b-new-mp-form.html` | New-MP form (`dest` prefilled), never submitted | R45 | 036, 048 |
| R46 | `R46-modo-alert-form.html` | Moderator alert form, GET only, never submitted | R46 | 036, 050 |
| R53a | `R53a-smiley-search-no-result.html` | Smiley search, no result: 40-byte text "Désolé, aucune réponse n'a été trouvée !" | R53 | 025, 053 |
| R53b | `R53b-smiley-search-one-word.html` | One word: 657 smileys | R53 | 025, 053 |
| R53c | `R53c-smiley-search-two-words.html` | Two words: 1010 smileys (words are OR-ed, not AND-ed) | R53 | 025, 053 |
| R54 | `R54-smiley-wiki-detail-anon.html` | Smiley wiki detail page | R54 | 053 |
| R55-p1 | `R55-p1-profile-edit-page1.html` | `/user/editprofil.php?page=1`: personal fields (redacted, birth date and gender unselected) | R55 | 025, 043, 044 |
| R55-p3 | `R55-p3-profile-edit-page3.html` | Page 3: display settings incl. `topicpp` (posts per page) | R55 | 025, 044 |
| R55-p5 | `R55-p5-profile-edit-page5.html` | Page 5: `hash_check` only form | R55 | 025, 043, 044 |
| R57a | `R57a-rest-categories.json` | REST categories (20) | R57 | 057 |
| R57b | `R57b-rest-category-topics-last.json` | REST last topics of cat 13 (25 per page) | R57 | 057 |
| R57c | `R57c-rest-topic.json` | REST one topic | R57 | 057 |
| W00 | `W00-login-form-anon.html` | Login page `login.php`: form `form1` fields | W01 (diagnosis) | 043 |
| W01 | `W01-login-failure.html` | Refused login (user1, stored credentials): `.hop` "Votre mot de passe ou nom d'utilisateur n'est pas valide", refresh to `/`, no cookie | W01 (stands in for W02) | 043 |
| W03 | `W03-login-success.html` | Login success (user2): "Vérification de votre identification...", refresh to `login_redirection.php`, cookies `md_user`, `md_passs`, `md_id` | W03 | 043, 042, 025 |

## Not captured

| Rows | Why |
|---|---|
| W02 | Dropped: W01's refusal already gives the failure page; a second failed login was not worth the lockout risk. |
| W10-W20, R02, R13, R14, R43, R44, R47, P03 | Need a working user1 session (MP threads between the two accounts). Pending a credential check by the operator. |
| R33, R34, R51, R58 | Dropped per the checklist (R58 folded into R08-2). |
| R50, R52, R56 | Not reached: the run stopped at the first HTTP 500 (R55 path check `/editprofil.php`). |
| oldcitation, Streamable/Dailymotion/Twitch, reho.st images | Not present on the pages picked; synthetic or a later capture. |
