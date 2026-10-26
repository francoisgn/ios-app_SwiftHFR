# Fixtures

Fixtures are real HFR pages used to test parsers, paired with the **oracle**: the output of the legacy parser on the same page.

## Layout
- **Shared capture corpus** (LOT-001): `Packages/HFRKit/Tests/HFRParsingTests/Fixtures/captures/<id>-<slug>.html`
  (`.json` for REST answers) plus `<id>.meta.json` (URL template, requested and final URL, redirect hops, status,
  content type, date, account role `anon`/`user1`/`user2`, names of cookies set, anonymized POST body). Ids follow the
  capture checklist rows; [`captures/MANIFEST.md`](../Packages/HFRKit/Tests/HFRParsingTests/Fixtures/captures/MANIFEST.md)
  lists what each file covers and which lots consume it. Captures are never edited by hand: re-capture and re-anonymize.
- **Per-lot oracles** (LOT-002..004 onwards): `Fixtures/<lot>/<case>.oracle.json`, the legacy parser output on a
  corpus file; `<case>` names the corpus id it was computed from. Hand-built synthetic pages for states that cannot be
  captured safely live next to them as `Fixtures/<lot>/<case>.synthetic.html`.

## Anonymization (mandatory before commit)
Replace, consistently within a fixture:
- pseudos and profile links of real members → `user1`, `user2`, …
- cookies, session IDs, `hash_check` and any form token → `REDACTED`
- private message content → placeholder text
- e-mail addresses, IPs → placeholders

Public forum post content may stay when needed for the test; prefer neutral excerpts.
A reviewer must check anonymization; gitleaks runs on every push as a safety net.

## Capture
Run on the maintainer's Mac with [`tooling/fixtures/flows.py`](../tooling/fixtures/flows.py) (one step per
invocation, shared 3 s delay and request budget, persistent per-account jars in the work folder outside the repo),
then `anonymize.py` on every raw file (`--private` for MP pages), `anonymize.py check`, and an independent grep of the
anonymized set for the real pseudos, cookie values and tokens. Raw captures stay in the work folder and are deleted
once the anonymized files are merged.
What to capture: the operator-approved [LOT-001 capture checklist](lots/LOT-001-capture-checklist.md) (read GETs, write flows limited to private messages between the two operator accounts, and what is covered by synthetic pages instead). Any new capture needs the operator's go first.

Tooling (Python 3 stdlib): [`tooling/fixtures/`](../tooling/fixtures/README.md) — `capture.py` (polite raw capture, outside the repo), `anonymize.py` (redaction, obfuscated-link decode and re-encode, `check` verifier). CI runs its unit tests, which use synthetic HTML only.
