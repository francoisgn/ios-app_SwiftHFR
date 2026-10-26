#!/usr/bin/env python3
"""Anonymize captured HFR pages before they are committed as fixtures (docs/FIXTURES.md).

    anonymize.py --config local.json [--private] in.html out.html
    anonymize.py check --config local.json [--private] file.html [...]

Python 3 stdlib only. Output is English; colors are disabled without a TTY or with NO_COLOR.
"""
import argparse
import html
import html.entities
import json
import os
import re
import sys
import urllib.parse

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import _ui  # noqa: E402

REDACTED = "REDACTED"
PRIVATE_PLACEHOLDER = "Private message content removed."
EMAIL_PLACEHOLDER = "redacted@example.invalid"
IP_PLACEHOLDER = "192.0.2.1"  # RFC 5737 documentation range
FAKE_ID_OPERATOR = 900001
FAKE_ID_OTHER = 910001

# Alphabet of the HFR link obfuscation: index in this string == nibble value.
ALPHABET = "0A12B34C56D78E9F"
# Legacy: RangeOfCharacters.m:92-114 (decodeSpanUrlFromString, prefix 20) and :117+ (…2, prefix 12);
# prefix names and lengths: docs/HFR-PROTOCOL.md §7 row E7.
PREFIXES = ("md_noclass_cryptlink", "md_blank_cryptlink", "md_cryptlink")
TOKEN_RE = re.compile(
    r"(?<![\w-])(%s)([0-9A-F]{2,})(?![0-9A-Za-z])" % "|".join(PREFIXES))

# md_passs / md_id: the cookie names HFR actually sets on login (live, LOT-001 fixture W03).
COOKIE_NAMES = r"md_user|md_passs|md_pass|md_id|md_forum|md_session|PHPSESSID|session_?id|sessid|sid"
COOKIE_RE = re.compile(r"(?<![\w])(%s)=([^;&\s\"'<>]+)" % COOKIE_NAMES, re.I)
COOKIE_OK = {"", REDACTED.lower(), "deleted"}
# codehex: per-session logout token of the authenticated `unlog.php` link (live, fixture R21).
HASH_RE = re.compile(
    r"((?:hash_check|codehex)(?:%3D|=|[\"']?\s*:\s*[\"']?))([^&\"'\s<>;)\\,]+)", re.I)
EMAIL_RE = re.compile(
    r"[A-Za-z0-9._+-]+(?:@|%40)[A-Za-z][A-Za-z0-9-]*(?:\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}")
_OCTET = r"(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)"
IP_RE = re.compile(r"(?<![\d.])%s(?:\.%s){3}(?!\d|\.\d)" % (_OCTET, _OCTET))
INPUT_RE = re.compile(r"<input\b[^>]*>", re.I | re.S)
VALUE_RE = re.compile(r"(\bvalue\s*=\s*)(?:([\"'])(.*?)\2|([^\s>\"']+))", re.I | re.S)
PROFIL_RE = re.compile(r"(profil-)(\d+)", re.I)
TOKEN_NAME_RE = re.compile(r"hash|token|csrf|nonce|sess|secret|pass|auth|sid|key", re.I)
TOKEN_VALUE_RE = re.compile(r"[A-Za-z0-9+/=_-]{20,}")
FIXED_INPUT_NAMES = {"hash_check", "md_user", "md_pass"}
# Personal fields of the profile edit form (editprofil.php page 1, fixture R55-p1).
PERSONAL_INPUT_NAMES = {"email", "emailconfirm", "homepage", "custom_ville", "custom_occupation", "custom_hobby"}
PERSONAL_SELECT_RE = re.compile(
    r"(<select\b[^>]*\bname=[\"'](?:bday|bmonth|byear|custom_sexe)[\"'][^>]*>)(.*?)(</select>)", re.I | re.S)
SELECTED_RE = re.compile(r"\s+selected(?:\s*=\s*(?:[\"'][^\"']*[\"']|[^\s>]+))?", re.I)
# Operator ids also appear as bare numbers ([quotemsg=…,…,<id>], md_id, user_id=): ids this long only.
MIN_BARE_ID_DIGITS = 5

# MP list subjects are private too (live R13u1); fixture threads, MPStorage title and page numbers stay.
SUBJECT_RE = re.compile(r"(<a\b[^>]*\bclass=[\"']cCatTopic[\"'][^>]*>)(.*?)(</a>)", re.I | re.S)
KEEP_SUBJECT_RE = re.compile(r"\s*(?:\d+|fixture-test[\w -]*|[0-9a-f]{32}|%s)\s*$" % re.escape("Private subject"))
PRIVATE_SUBJECT = "Private subject"
PARA_OPEN_RE = re.compile(r"<(\w+)\b[^>]*\bid=([\"'])para[^\"']*\2[^>]*>", re.I)

# Member pseudos other than the operator's: where HFR prints them (selectors cite the legacy parser).
# ParseMessagesOperation.m:149 (author = class "s2"), :380 (profile link), :200-220 (quotes).
_ECRIT = r"(?:écrit|&eacute;crit|&#0*233;crit)"
DISCOVER = (
    (re.compile(r"<(\w+)\b[^>]*\bclass=[\"']s2[\"'][^>]*>(.*?)</\1>", re.I | re.S), 2),
    (re.compile(r">\s*([^<>]{1,60}?)\s+a\s+%s\s*:" % _ECRIT, re.I), 1),
    (re.compile(r"(?:édité|&eacute;dit&eacute;|&#0*233;dit&#0*233;)\s+par\s+([^<>]{1,60}?)\s+le\b", re.I), 1),
    (re.compile(r"\b(?:spseudo|pseudo|dest)=([^&\"'\s<>]+)", re.I), 1),
    (re.compile(r"<input\b[^>]*\bname=[\"'](?:pseudo|spseudo|dest)[\"'][^>]*\bvalue=[\"']([^\"']*)", re.I), 1),
    (re.compile(r"<a\b[^>]*href=[\"'][^\"']*profil-\d+[^\"']*[\"'][^>]*>([^<]+)</a>", re.I), 1),
)
NOT_A_MEMBER = {"", "publicité", "publicite", "anonyme", REDACTED.lower()}
FAKE_NAME_RE = re.compile(r"user\d+$")
# Zero-width characters HFR keeps inside some printed pseudos (live R21) but not in their links.
ZERO_WIDTH = "\u200b\u200c\u200d\ufeff"
_ZW_TOKEN = r"(?:[%s]|&#0*(?:8203|8204|8205|65279);|&#x0*(?:200b|200c|200d|feff);)" % ZERO_WIDTH
ZW_TOKEN_RE = re.compile(_ZW_TOKEN, re.I)


def name_key(name):
    """Alias lookup key: lower case, zero-width characters removed."""
    return re.sub("[%s]" % ZERO_WIDTH, "", name).lower()


def encode_payload(text):
    """Obfuscate text: each byte becomes two characters of ALPHABET (high nibble first)."""
    out = []
    for b in text.encode("utf-8", "surrogateescape"):
        out.append(ALPHABET[b >> 4] + ALPHABET[b & 15])
    return "".join(out)


def decode_payload(payload):
    """Reverse of encode_payload; None when the payload is not a printable ASCII string."""
    if len(payload) % 2:
        return None
    raw = bytearray()
    for i in range(0, len(payload), 2):
        hi, lo = ALPHABET.find(payload[i]), ALPHABET.find(payload[i + 1])
        if hi < 0 or lo < 0:
            return None
        raw.append(hi * 16 + lo)
    if not all(0x20 <= b <= 0x7E for b in raw):
        return None
    return raw.decode("ascii")


def iter_tokens(text):
    """Yield (position, prefix, payload, decoded-or-None) for every obfuscated class token.

    Mirrors the legacy guard (ObjCMessageActionsBuilder.m:80-89): only strings longer than 20
    characters are decoded, and a decoded value must look like a URL part (printable ASCII).
    """
    for m in TOKEN_RE.finditer(text):
        prefix, payload = m.group(1), m.group(2)
        decoded = decode_payload(payload) if len(prefix) + len(payload) > 20 else None
        yield m.start(), prefix, payload, decoded, m


def _char_alts(ch):
    # Entities and %-escapes are not covered by re.I, so enumerate both letter cases explicitly.
    alts = [re.escape(ch)]
    for c in sorted({ch, ch.lower(), ch.upper()}):
        if len(c) != 1:
            continue
        cp = ord(c)
        if c == " ":
            alts += [r"\+", "&nbsp;"]
        alts.append("".join("%%%02X" % b for b in c.encode("utf-8")))
        if cp < 256:
            alts.append("%%%02X" % cp)
        alts += ["&#0*%d;" % cp, "&#x0*%x;" % cp]
        # HFR also %-encodes an already entity-escaped pseudo in URLs (dest=a%26%23039%3Bb, live R01).
        alts += ["%%26%%23(?:0*%d|x0*%x)%%3B" % (cp, cp)]
        name = html.entities.codepoint2name.get(cp)
        if name:
            alts += ["&%s;" % name, "%%26%s%%3B" % name]
        if c == "'":
            alts += ["&apos;", "%26apos%3B"]
    return "(?:%s)" % "|".join(dict.fromkeys(alts))


def pseudo_regex(pseudo):
    """Regex matching a pseudo in any mix of raw, %-encoded and HTML-entity forms, case-insensitively."""
    zw = _ZW_TOKEN + "*"
    body = zw.join(_char_alts(c) for c in name_key(pseudo))
    return re.compile(
        r"(?:(?<![A-Za-z0-9])|(?<=%[0-9A-Fa-f]{2}))" + body + r"(?![A-Za-z0-9])", re.I)


def _attr(tag, name):
    m = re.search(r"\b%s\s*=\s*(?:([\"'])(.*?)\1|([^\s>\"']+))" % name, tag, re.I | re.S)
    if not m:
        return None
    return m.group(2) if m.group(1) else m.group(3)


def _sensitive_input(tag):
    name = (_attr(tag, "name") or "").lower()
    typ = (_attr(tag, "type") or "").lower()
    value = _attr(tag, "value")
    if value is None or value in ("", REDACTED):
        return False
    if name in FIXED_INPUT_NAMES or name in PERSONAL_INPUT_NAMES:
        return True
    if typ == "hidden":
        return bool(TOKEN_NAME_RE.search(name) or TOKEN_VALUE_RE.fullmatch(value))
    return False


def _find_para_blocks(text):
    """Yield (inner_start, inner_end) of every element whose id starts with `para` (message body)."""
    pos = 0
    while True:
        m = PARA_OPEN_RE.search(text, pos)
        if not m:
            return
        tag = m.group(1)
        tag_re = re.compile(r"<(/?)%s\b[^>]*>" % re.escape(tag), re.I)
        depth, end = 1, None
        for t in tag_re.finditer(text, m.end()):
            depth += -1 if t.group(1) else 1
            if depth == 0:
                end = t.start()
                break
        if end is None:
            end = len(text)
        yield m.end(), end
        pos = max(end, m.end())


def _strip_tags(s):
    return html.unescape(re.sub(r"<[^>]*>", "", s)).strip()


def line_of(text, pos):
    """1-based line number of a character offset."""
    return text.count("\n", 0, pos) + 1


class Config:
    """Operator-local settings: real pseudos (→ user1…), e-mails and profile ids to hide."""

    def __init__(self, pseudos=(), emails=(), profile_ids=()):
        self.pseudos = [p for p in pseudos if p]
        self.emails = [e for e in emails if e]
        # A null entry keeps the position (user1 -> 900001, user2 -> 900002) for an unknown id.
        self.profile_ids = ["" if i is None else str(i) for i in profile_ids]

    @classmethod
    def load(cls, path):
        """Load and validate a JSON config file."""
        with open(path, encoding="utf-8") as fh:
            data = json.load(fh)
        for key in ("pseudos", "emails", "profile_ids"):
            if key in data and not isinstance(data[key], list):
                raise ValueError("config key %r must be a list" % key)
        return cls(data.get("pseudos", []), data.get("emails", []), data.get("profile_ids", []))


class Anonymizer:
    """Stateless across files for the operator's identity, fresh per call for other members."""

    def __init__(self, config):
        self.config = config
        self.names = {}      # lowercase pseudo -> fake name for the current file
        self.ids = {}        # real profile id -> fake id for the current file
        self.stats = {}
        self._regex_cache = {}

    # -- state ----------------------------------------------------------------
    def _reset(self):
        self.names = {name_key(p): "user%d" % (i + 1) for i, p in enumerate(self.config.pseudos)}
        self.ids = {pid: str(FAKE_ID_OPERATOR + i) for i, pid in enumerate(self.config.profile_ids) if pid}
        self.stats = {"tokens": 0, "undecoded_tokens": 0, "others": 0, "private_blocks": 0}

    def _rx(self, pseudo):
        if pseudo not in self._regex_cache:
            self._regex_cache[pseudo] = pseudo_regex(pseudo)
        return self._regex_cache[pseudo]

    # -- discovery of other members --------------------------------------------
    def discover(self, text, base=0):
        """Return [(name, pos)] of member pseudos printed in text, in document order."""
        found = []
        for rx, group in DISCOVER:
            for m in rx.finditer(text):
                raw = m.group(group)
                if group == 2 and rx is DISCOVER[0][0]:
                    raw = _strip_tags(raw)
                name = html.unescape(urllib.parse.unquote_plus(raw)).strip()
                low = name_key(name)
                if low in NOT_A_MEMBER or len(name) > 50 or re.search(r"[=<>]", name):
                    continue
                found.append((name, base + m.start(group)))
        return found

    # -- redaction --------------------------------------------------------------
    def redact_text(self, s):
        """Apply every redaction except the obfuscated-link pass and private-body removal."""
        def inp(m):
            tag = m.group(0)
            if not _sensitive_input(tag):
                return tag
            return VALUE_RE.sub(lambda v: v.group(1) + (v.group(2) or "") + REDACTED + (v.group(2) or ""), tag, count=1)
        s = INPUT_RE.sub(inp, s)
        s = HASH_RE.sub(lambda m: m.group(1) + REDACTED if m.group(2) != REDACTED else m.group(0), s)
        s = COOKIE_RE.sub(
            lambda m: m.group(0) if m.group(2).lower() in COOKIE_OK else m.group(1) + "=" + REDACTED, s)
        for e in self.config.emails:
            s = re.sub(re.escape(e), EMAIL_PLACEHOLDER, s, flags=re.I)
        s = EMAIL_RE.sub(EMAIL_PLACEHOLDER, s)
        s = IP_RE.sub(lambda m: m.group(0) if m.group(0).startswith("192.0.2.") else IP_PLACEHOLDER, s)

        def prof(m):
            pid = m.group(2)
            if pid in self.ids.values():
                return m.group(0)
            if pid not in self.ids:
                own = len([p for p in self.config.profile_ids if p])
                self.ids[pid] = str(FAKE_ID_OTHER + len(self.ids) - own)
            return m.group(1) + self.ids[pid]
        s = PROFIL_RE.sub(prof, s)
        for i, pid in enumerate(self.config.profile_ids):
            if len(pid) >= MIN_BARE_ID_DIGITS:
                s = re.sub(r"(?<!\d)%s(?!\d)" % pid, str(FAKE_ID_OPERATOR + i), s)
        s = PERSONAL_SELECT_RE.sub(lambda m: m.group(1) + SELECTED_RE.sub("", m.group(2)) + m.group(3), s)
        for name in sorted(self.names, key=len, reverse=True):
            fake = self.names[name]
            # The alias is shared; zero-width characters of the original stay, right after it.
            s = self._rx(name).sub(lambda m, f=fake: f + "".join(ZW_TOKEN_RE.findall(m.group(0))), s)
        return s

    def anonymize(self, text, private=False):
        """Return the anonymized page. Mapping of other members is consistent within this call."""
        self._reset()
        if private:
            parts, last = [], 0
            for start, end in _find_para_blocks(text):
                if start < last:
                    continue
                parts += [text[last:start], PRIVATE_PLACEHOLDER]
                last = end
                self.stats["private_blocks"] += 1
            text = "".join(parts) + text[last:]
            text = SUBJECT_RE.sub(lambda m: m.group(0) if KEEP_SUBJECT_RE.match(_strip_tags(m.group(2)))
                                  else m.group(1) + PRIVATE_SUBJECT + m.group(3), text)
        # Discover other members in the page and inside obfuscated links, in document order.
        found = self.discover(text)
        tokens = list(iter_tokens(text))
        for pos, _prefix, _payload, decoded, _m in tokens:
            if decoded is not None:
                found += self.discover(decoded, pos)
        for name, _pos in sorted(found, key=lambda f: f[1]):
            if name_key(name) not in self.names and not FAKE_NAME_RE.match(name_key(name)):
                self.names[name_key(name)] = "user%d" % (len(self.names) + 1)
                self.stats["others"] += 1
        # Obfuscated links: decode, redact, re-encode with the same prefix.
        out, last = [], 0
        for _pos, prefix, payload, decoded, m in tokens:
            if decoded is None:
                self.stats["undecoded_tokens"] += 1
                continue
            out += [text[last:m.start()], prefix, encode_payload(self.redact_text(decoded))]
            last = m.end()
            self.stats["tokens"] += 1
        text = "".join(out) + text[last:]
        return self.redact_text(text)

    # -- verification -----------------------------------------------------------
    def findings(self, text, private=False):
        """Return [(line, reason, excerpt)] for every leak left in text (including decoded links)."""
        self._reset()
        res = []

        def scan(chunk, base, where):
            def add(pos, reason):
                line = line_of(text, base + pos if where == "" else base)
                start = chunk.rfind("\n", 0, pos) + 1
                end = chunk.find("\n", pos)
                excerpt = chunk[start:end if end >= 0 else len(chunk)].strip()[:200]
                res.append((line, reason + where, excerpt))
            for p in self.config.pseudos:
                for m in self._rx(p).finditer(chunk):
                    add(m.start(), "real pseudo")
            for e in self.config.emails:
                for m in re.finditer(re.escape(e), chunk, re.I):
                    add(m.start(), "operator e-mail")
            for m in EMAIL_RE.finditer(chunk):
                if m.group(0) != EMAIL_PLACEHOLDER:
                    add(m.start(), "e-mail address")
            for m in IP_RE.finditer(chunk):
                if not m.group(0).startswith("192.0.2."):
                    add(m.start(), "IP address")
            for m in HASH_RE.finditer(chunk):
                if m.group(2) != REDACTED:
                    add(m.start(), "hash_check value not REDACTED")
            for m in COOKIE_RE.finditer(chunk):
                if m.group(2).lower() not in COOKIE_OK:
                    add(m.start(), "cookie/session value (%s)" % m.group(1))
            for m in INPUT_RE.finditer(chunk):
                if _sensitive_input(m.group(0)):
                    add(m.start(), "hidden token input not REDACTED")
            for m in PROFIL_RE.finditer(chunk):
                if m.group(2) in self.config.profile_ids:
                    add(m.start(), "operator profile id")
            for pid in self.config.profile_ids:
                if len(pid) >= MIN_BARE_ID_DIGITS:
                    for m in re.finditer(r"(?<!\d)%s(?!\d)" % pid, chunk):
                        add(m.start(), "operator profile id (bare number)")
            for m in PERSONAL_SELECT_RE.finditer(chunk):
                if SELECTED_RE.search(m.group(2)):
                    add(m.start(), "personal profile field still selected")
            for name, pos in self.discover(chunk):
                if not FAKE_NAME_RE.match(name_key(name)) and name_key(name) not in {
                        name_key(p) for p in self.config.pseudos}:
                    add(pos, "member pseudo not anonymized")
        scan(text, 0, "")
        for pos, _prefix, _payload, decoded, _m in iter_tokens(text):
            if decoded is not None:
                scan(decoded, pos, " (in obfuscated link)")
        if private:
            for m in SUBJECT_RE.finditer(text):
                if not KEEP_SUBJECT_RE.match(_strip_tags(m.group(2))):
                    res.append((line_of(text, m.start()), "private MP subject not replaced", ""))
            for start, end in _find_para_blocks(text):
                if _strip_tags(text[start:end]) != PRIVATE_PLACEHOLDER:
                    res.append((line_of(text, start), "private message body not replaced", ""))
        return sorted(set(res))


def read_text(path):
    """Read a page as UTF-8, falling back to ISO-8859-1 (legacy: LoginService.swift:137-140)."""
    with open(path, "rb") as fh:
        raw = fh.read()
    try:
        return raw.decode("utf-8"), "utf-8"
    except UnicodeDecodeError:
        return raw.decode("latin-1"), "latin-1"


def cmd_anonymize(args):
    """CLI: anonymize one file, then verify the output."""
    anon = Anonymizer(Config.load(args.config))
    text, enc = read_text(args.input)
    out = anon.anonymize(text, private=args.private)
    leaks = anon.findings(out, private=args.private)
    if leaks:
        for line, reason, excerpt in leaks:
            _ui.ko("%s:%d: %s: %s" % (args.output, line, reason, excerpt))
        _ui.ko("output NOT written: anonymization is incomplete")
        return 1
    with open(args.output, "w", encoding=enc, newline="") as fh:
        fh.write(out)
    s = anon.stats
    _ui.ok("%s -> %s (%d obfuscated links re-encoded, %d other members, %d private bodies)" % (
        args.input, args.output, s["tokens"], s["others"], s["private_blocks"]))
    if s["undecoded_tokens"]:
        _ui.warn("%d obfuscated token(s) could not be decoded and were left as is" % s["undecoded_tokens"])
    return 0


def cmd_check(args):
    """CLI: verify files; exit non-zero on the first file with a leak."""
    anon = Anonymizer(Config.load(args.config))
    bad = 0
    for path in args.files:
        text, _enc = read_text(path)
        leaks = anon.findings(text, private=args.private)
        for line, reason, excerpt in leaks:
            _ui.ko("%s:%d: %s: %s" % (path, line, reason, excerpt))
        if leaks:
            bad += 1
        else:
            _ui.ok("%s: clean" % path)
    return 1 if bad else 0


def main(argv=None):
    """Entry point."""
    argv = list(sys.argv[1:] if argv is None else argv)
    if argv and argv[0] == "check":
        p = argparse.ArgumentParser(prog="anonymize.py check", description="Verify anonymized files.")
        p.add_argument("--config", required=True)
        p.add_argument("--private", action="store_true", help="also require message bodies to be replaced")
        p.add_argument("files", nargs="+")
        return cmd_check(p.parse_args(argv[1:]))
    p = argparse.ArgumentParser(prog="anonymize.py", description="Anonymize a captured HFR page.")
    p.add_argument("--config", required=True, help="local JSON config (git-ignored)")
    p.add_argument("--private", action="store_true", help="replace message bodies (private messages)")
    p.add_argument("input")
    p.add_argument("output")
    args = p.parse_args(argv)
    if os.path.abspath(args.input) == os.path.abspath(args.output):
        _ui.ko("input and output must differ")
        return 2
    return cmd_anonymize(args)


if __name__ == "__main__":
    sys.exit(main())
