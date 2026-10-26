# LOT-026 — Poll parser (voting form)

- **Module:** HFRParsing
- **Difficulty / model:** medium (Sonnet → Opus)
- **Issue:** none (lot tracked in `docs/LOTS.md`)

Scope decided by the orchestrator: the parser covers **only what captures `R32a` (logged out) and `R32b` (logged in, not voted) show**.
No closed, voted or result-bar code path and no hand-built fixture: the Mac will capture R33. Vote responses (N05) belong to LOT-054.

## Legacy sources

Legacy repository <https://github.com/francoisgn/hfrnow> at `2440d79`. Audit: [B9](../audit/B-list-parsing-models.md), [C07](../audit/C-message-parsing.md), [D §2.9](../audit/D-posting.md).

| Legacy | Replaced by |
|---|---|
| `Classes/ObjCTopicPageWorker.m:159-162` (first element with class exactly `sondage`, raw HTML handed to Swift) | `PollParser.poll(in:)` finds `div.sondage` itself, in a full page or a fragment |
| `HFRswift/Swift/PollData.swift:104-250` (`PollHTMLParser`: question `<b class="s2">`, options `li`/`input`/`label`, hidden fields) | same, on the DOM instead of regexes |

## Behaviour

`PollParser.poll(in: String) throws(ParsingError) -> Poll?` (model `Poll`, `PollOption` unchanged in HFRModels):

- nil when the page has no element with class token `sondage` (`R20`, `R23`, `R31`).
- `question`: text of the `s2` element, `&nbsp;` as space, whitespace collapsed.
- `options`: one per `<li>` holding an input and a `<label>`; `id` = 1-based position; `fieldName` = input `name` (`reponse`); the input must be a radio.
  In both captures the radio `value`s are `1...10`, equal to the position, which settles the "radio value semantics" question of D §2.9 for single choice.
- `kind = .votable(options, hiddenFields)`: `hiddenFields` = every `input[type=hidden]` **inside** the `sondage` block: `cat, p, page, sondage, owntopic, subcat, numeropost, hash_check`
  (`hash_check` is `""` when logged out, a 32-hex token when logged in). The form also prints `hash_check` once before the block (same value).
- `footer = nil`, `maxChoices = 1`: no capture shows a footer or a multi-choice hint.
- Anything else inside a `sondage` block (no answer row, a non-radio input, no `s2`) is a typed `ParsingError`, never a guess.

Facts for LOT-054 (vote POST), asserted by tests on the captures: the block sits in `<form method="post" action="/user/vote.php?config=hfr.inc">`;
the form has two submit buttons with the **same name** `sondage_submit`: "Voter" and "Voir les résultats" (the latter shows results and forfeits the vote, per the page text);
legacy sent neither (`PollData.swift:44-100`), so whether the server needs `sondage_submit=Voter` is **unverified**; the form has no `verifrequet`.

## Edge cases

Fragment instead of page; `sondageLeft` (a different class) is not the block; labels with `&amp;`, `&nbsp;`, double spaces; empty token logged out; token not printed by `Poll`'s description.

## Fixtures

`R32a-topic-poll-anon.html`, `R32b-topic-poll-logged-in-not-voted.html` (poll `98162`, ten answers); `R20`, `R23`, `R31` for "no poll". No synthetic file.
Note: **R32a does not show results** for an anonymous visitor (the checklist expected it to): it shows the same voting form, with an empty token.

## Pending R33 (to port once captured)

States no fixture proves yet; the parser refuses them with `missingElement("li input in poll block")` / `invalidValue(field: "poll answer input type")`.
Legacy to port, in `HFRswift/Swift/PollData.swift` unless stated:

| State | What to port |
|---|---|
| Already voted / closed (results) | `extractResults` `:253-355`: `div.sondageLeft` with two `div.sondageTop` (percentage, vote count) and `div.sondageRight` label, paired by index; `Poll.Kind.results`. The older `Classes/PollTableViewController.m:150-205` reads the same blocks by child position. Decimal comma (`16,7`) is not handled by legacy (`:330`) and must be |
| Footer | `extractFooter` `:164-181` (`div.sondageFooter*`, `<br>` to newline); ObjC takes the last child of the block (`PollTableViewController.m:99`) |
| Multi-choice | `extractMaxChoices` `:185-206` (a number between spaces in the text between the question and `<ol type="1">`), checkbox inputs, vote value `"1"` per field (`:44-100`, D §2.9); field names (`reponse<N>`, E11) |
| Mode rule | legacy: any `<input` in the block means voting, otherwise results (`:115-141`); with R33, check what a voted poll still prints (inputs, "Voir les résultats" text) |

## Intentional differences from legacy

- DOM parsing instead of regexes; hidden inputs without a `value` give `""`.
- Unknown shapes throw instead of returning nil or a half-filled poll.

## Learnings

- A checklist expectation ("results as anon") can be wrong: read the capture before designing the state machine.
