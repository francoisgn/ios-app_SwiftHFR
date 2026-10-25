# Fixture kit

Python 3 standard library only (no dependency). Output is English, colored only on a TTY (`NO_COLOR` disables it).
Policy: [docs/FIXTURES.md](../../docs/FIXTURES.md). Protocol facts: [docs/HFR-PROTOCOL.md](../../docs/HFR-PROTOCOL.md) §4-5.

| File | Role |
|---|---|
| `capture.py` | Polite capture of the pages listed in a manifest (operator-run, Mac) |
| `anonymize.py` | Anonymizer library, CLI and `check` verifier |
| `local.example.json` | Template of the git-ignored `local.json` |
| `tests/` | `python3 -m unittest discover tooling/fixtures/tests` (synthetic HTML only, run in CI) |

## Safety rules

1. Raw captures live **outside any git work tree** (`capture.py` refuses otherwise), for example `~/agent-work/<task>/raw/`.
2. `local.json` (real pseudos, e-mail) and the credentials file are never committed (`local.json` is git-ignored).
3. Only anonymized output is committed. Run `anonymize.py check` on it first.
4. Delete the raw captures once the anonymized files are committed.
5. Nothing is sent to the forum except what the manifest lists; GET only.

## Local config (`local.json`)

```json
{
  "pseudos": ["FirstRealPseudo", "SecondRealPseudo"],
  "emails": ["operator@example.org"],
  "profile_ids": [111111, 222222]
}
```

- `pseudos`: mapped to `user1`, `user2`... in this order. Any other member found in author blocks (`class="s2"`), quotes (`X a écrit :`), edit notices, profile links or `pseudo=`/`dest=` parameters becomes `user3`, `user4`... in document order, consistently within one file.
- `profile_ids`: the operator's `profil-NNN` ids become `900001`...; other members' ids become `910001`...
- `emails`: redacted in addition to every e-mail-looking string.

## Anonymize and verify

```sh
python3 tooling/fixtures/anonymize.py --config tooling/fixtures/local.json raw/topic.html out/topic.html
python3 tooling/fixtures/anonymize.py --config tooling/fixtures/local.json --private raw/mp.html out/mp.html
python3 tooling/fixtures/anonymize.py check --config tooling/fixtures/local.json out/*.html
```

What is redacted: pseudos in any form (raw, `%`-encoded, HTML entities, any case), `hash_check` (inputs, URLs, JS), cookie and session values (`md_user`, `md_pass`, `md_forum`, `PHPSESSID`, `sessid`, `sid`), hidden token-like inputs, e-mails, IPv4 addresses (replaced by `192.0.2.1`), profile ids.

Obfuscated links (`md_noclass_cryptlink`, `md_blank_cryptlink`, `md_cryptlink` class tokens) are decoded (alphabet `0A12B34C56D78E9F`, two characters per byte), redacted, then **re-encoded with the same prefix** so the fixture keeps the real structure. Check mode decodes them too and reports the line of the token. `--private` replaces the content of every element whose `id` starts with `para` (message body) by a placeholder; `check --private` verifies it.

The CLI runs `check` on its own output and writes nothing if a leak remains. `check` exits non-zero and prints each offending line.

## Capture

```sh
python3 tooling/fixtures/capture.py --manifest manifest.json --out ~/agent-work/<task>/raw --dry-run
python3 tooling/fixtures/capture.py --credentials creds.json --manifest manifest.json --out ~/agent-work/<task>/raw
```

`creds.json` (JSON only, outside the repo): `{"accounts": [{"pseudo": "...", "password": "..."}, {"pseudo": "...", "password": "..."}]}`. The first entry is `user1`, the second `user2`.

`manifest.json`: `{"pages": [{"id": "topic-p1", "url": "/forum2.php?config=hfr.inc&cat=13&post=1", "account": "anon", "method": "GET"}]}` with `account` one of `anon`, `user1`, `user2`.

Login is `POST /login_validation.php?config=hfr.inc`; success means the body contains `login_redirection.php`. One request at least every 3 s (`--delay` can only raise it), a spinner while waiting, stop on HTTP 429 or 5xx. Credentials and cookie values are never printed; saved headers have `Set-Cookie` values replaced.
