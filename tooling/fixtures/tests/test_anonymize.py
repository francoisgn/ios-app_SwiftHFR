"""Tests for anonymize.py. All HTML here is synthetic: no real pseudo, cookie or token."""
import os
import sys
import tempfile
import unittest
import urllib.parse

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import anonymize as A  # noqa: E402

REAL1, REAL2, OTHER = "Zorglub", "Frobnitz", "Quuxbar"
CFG = A.Config(pseudos=[REAL1, REAL2], emails=["me@example.org"], profile_ids=[4242, 4343])


def obf(prefix, text):
    """Build an obfuscated class token the way HFR does."""
    return prefix + A.encode_payload(text)


def anon(html, private=False):
    return A.Anonymizer(CFG).anonymize(html, private=private)


def leaks(html, private=False):
    return A.Anonymizer(CFG).findings(html, private=private)


class CodecTests(unittest.TestCase):
    def test_round_trip(self):
        url = "/message.php?config=hfr.inc&cat=13&post=1&numreponse=7&hash_check=abc"
        self.assertEqual(A.decode_payload(A.encode_payload(url)), url)

    def test_alphabet_known_vector(self):
        # 'h' = 0x68 -> nibbles 6 and 8 -> "0A12B34C56D78E9F"[6]='4', [8]='5' (worked by hand)
        self.assertEqual(A.encode_payload("h"), "45")
        self.assertEqual(A.decode_payload("45"), "h")

    def test_non_printable_payload_is_not_decoded(self):
        self.assertIsNone(A.decode_payload("00"))  # byte 0x00
        self.assertIsNone(A.decode_payload("ZZ"))
        self.assertIsNone(A.decode_payload("0A1"))  # odd length

    def test_prefix_lengths(self):
        self.assertEqual([len(p) for p in A.PREFIXES], [20, 18, 12])

    def test_each_prefix_is_found_and_decoded(self):
        url = "/forum2.php?config=hfr.inc&cat=13&post=1234&page=2"
        for prefix in A.PREFIXES:
            html = '<div class="%s"></div>' % obf(prefix, url)
            toks = list(A.iter_tokens(html))
            self.assertEqual(len(toks), 1, prefix)
            self.assertEqual(toks[0][1], prefix)
            self.assertEqual(toks[0][3], url)

    def test_legacy_guard_short_strings_not_decoded(self):
        # prefix + payload must be longer than 20 characters (ObjCMessageActionsBuilder.m:80-89)
        html = '<a class="%s">' % obf("md_cryptlink", "ab")
        self.assertIsNone(list(A.iter_tokens(html))[0][3])


class RedactionTests(unittest.TestCase):
    def test_pseudo_variants(self):
        variants = [
            REAL1, REAL1.upper(), REAL1.lower(),
            urllib.parse.quote(REAL1), "".join("&#%d;" % ord(c) for c in REAL1),
            "".join("&#x%x;" % ord(c) for c in REAL1),
            REAL1[:3] + "&#" + str(ord(REAL1[3])) + ";" + REAL1[4:],
            REAL1.replace("o", "%6F"),
        ]
        for v in variants:
            html = '<b class="s2">%s</b> <a href="/x?pseudo=%s">v</a>' % (v, v)
            out = anon(html)
            self.assertNotIn(v, out, v)
            self.assertEqual(out.count("user1"), 2, v)
            self.assertEqual(leaks(out), [], v)

    def test_special_character_pseudo_forms(self):
        cfg = A.Config(pseudos=["A&B o'c", "Zoé"])
        a = A.Anonymizer(cfg)
        for v in ["A&amp;B o&#039;c", "A%26B+o%27c", "A&B&nbsp;o&apos;c", "Zo%C3%A9", "Zo&eacute;", "Zo&#233;", "Zo%E9"]:
            out = a.anonymize("<i>%s</i>" % v)
            self.assertRegex(out, r"<i>user[12]</i>", v)

    def test_pseudo_order_gives_user_numbers(self):
        out = anon("%s then %s" % (REAL2, REAL1))
        self.assertEqual(out, "user2 then user1")

    def test_other_members_consistent_within_file(self):
        html = ('<b class="s2"><a href="/hfr/profil-9001.htm">%s</a></b>'
                '<b class="s1"><a class="Topic">%s a écrit :</a></b>' % (OTHER, OTHER.lower()))
        out = anon(html)
        self.assertNotIn(OTHER.lower(), out.lower())
        self.assertEqual(out.count("user3"), 2)
        self.assertEqual(leaks(out), [])

    def test_two_other_members_numbered_in_document_order(self):
        html = '<b class="s2">Aaaa</b><b class="s2">Bbbb</b><b class="s2">Aaaa</b>'
        self.assertEqual(anon(html), '<b class="s2">user3</b><b class="s2">user4</b><b class="s2">user3</b>')

    def test_hash_check_everywhere(self):
        secret = "0123456789abcdef0123456789abcdef"
        html = ('<input type="hidden" name="hash_check" value="%s" />'
                '<input value=\'%s\' name=hash_check type=hidden>'
                '<a href="/modo/x.php?cat=1&amp;hash_check=%s&amp;p=2">x</a>'
                '<script>var h = "hash_check=%s"; var o = {hash_check: \'%s\'};</script>'
                % ((secret,) * 5))
        out = anon(html)
        self.assertNotIn(secret, out)
        self.assertIn("p=2", out)  # neighbouring parameters survive
        self.assertEqual(leaks(out), [])

    def test_hash_check_in_obfuscated_url_is_redacted_and_still_encoded(self):
        secret = "deadbeefdeadbeefdeadbeef"
        url = "/message.php?config=hfr.inc&cat=13&post=1&numreponse=5&hash_check=%s&pseudo=%s" % (secret, REAL1)
        html = '<td class="%s">x</td>' % obf("md_noclass_cryptlink", url)
        out = anon(html)
        tok = list(A.iter_tokens(out))
        self.assertEqual(len(tok), 1)
        self.assertEqual(tok[0][1], "md_noclass_cryptlink")  # same prefix kept
        decoded = tok[0][3]
        self.assertIsNotNone(decoded)
        self.assertIn("hash_check=REDACTED", decoded)
        self.assertIn("pseudo=user1", decoded)
        self.assertIn("numreponse=5", decoded)
        self.assertNotIn(secret, out)

    def test_pseudo_only_in_obfuscated_url_other_member(self):
        url = "/message.php?config=hfr.inc&cat=prive&dest=%s&p=1&subcat=" % OTHER
        out = anon('<a class="%s">x</a>' % obf("md_blank_cryptlink", url))
        decoded = list(A.iter_tokens(out))[0][3]
        self.assertIn("dest=user3", decoded)

    def test_cookies_and_session_ids(self):
        html = ("Set-Cookie: md_user=%s; path=/\nCookie: md_pass=s3cr3tvalue; PHPSESSID=abc123def456\n"
                "<script>document.cookie='sessid=zzz999';</script>" % REAL1)
        out = anon(html)
        for secret in ("s3cr3tvalue", "abc123def456", "zzz999", REAL1):
            self.assertNotIn(secret, out)
        self.assertIn("md_pass=REDACTED", out)
        self.assertEqual(leaks(out), [])

    def test_hidden_token_inputs(self):
        html = ('<input type="hidden" name="csrf_x" value="short" />'
                '<input type="hidden" name="whatever" value="Ab12Cd34Ef56Gh78Ij90Kl12" />'
                '<input type="hidden" name="cat" value="13" />')
        out = anon(html)
        self.assertEqual(out.count("REDACTED"), 2)
        self.assertIn('name="cat" value="13"', out)

    def test_emails_and_ips(self):
        html = "mail me@example.org or other.person+tag@mail.example.com from 203.0.113.77 retina logo@2x.png v1.2.3.4x"
        out = anon(html)
        self.assertNotIn("me@example.org", out)
        self.assertNotIn("other.person", out)
        self.assertNotIn("203.0.113.77", out)
        self.assertIn("logo@2x.png", out)
        self.assertEqual(leaks(out), [])

    def test_profile_ids(self):
        html = '<a href="/hfr/profil-4242.htm">a</a><a href="/hfr/profil-7777.htm">b</a><a href="/hfr/profil-4242.htm">c</a>'
        out = anon(html)
        self.assertEqual(out.count("profil-900001.htm"), 2)
        self.assertIn("profil-910001.htm", out)
        self.assertNotIn("4242", out)
        self.assertNotIn("7777", out)

    def test_private_mp_list_subjects(self):
        html = ('<a class="cCatTopic" href="/a">Weekend chez Paul</a><a class="cCatTopic" href="/b">fixture-test-1</a>'
                '<a class="cCatTopic" href="/c">a2bcc09b796b8c6fab77058ff8446c34</a><a class="cCatTopic" href="/d">12</a>')
        self.assertTrue(leaks(html, private=True))
        self.assertFalse(leaks(html))  # public topic titles are not private
        out = anon(html, private=True)
        self.assertNotIn("Paul", out)
        for kept in ("fixture-test-1", "a2bcc09b796b8c6fab77058ff8446c34", ">12<", ">Private subject<"):
            self.assertIn(kept, out)
        self.assertEqual(leaks(out, private=True), [])

    def test_zero_width_variant_shares_alias(self):
        # Live R21: the author block prints the pseudo with U+200B, the MP link without it.
        html = ('<b class="s2">Quu\u200bxbar</b> <a href="/message.php?cat=prive&dest=Quuxbar">mp</a> '
                '<b class="s2">Other</b>')
        out = anon(html)
        self.assertIn('<b class="s2">user3\u200b</b>', out.replace("user3\u200b", "user3\u200b"))
        self.assertIn("dest=user3", out)
        self.assertIn('<b class="s2">user4</b>', out)
        self.assertNotIn("Quu", out)
        self.assertEqual(leaks(out), [])
        # A real operator pseudo split by a zero-width joiner is still caught and mapped.
        out = anon("<b class=\"s2\">Zorg\u200dlub</b>")
        self.assertNotIn("Zorg", out)
        self.assertIn("user1", out)

    def test_url_encoded_entity_pseudo(self):
        cfg = A.Config(pseudos=["d'Artagnan"])
        html = '<a href="/message.php?dest=d%26%23039%3BArtagnan">x</a> d&#039;Artagnan'
        out = A.Anonymizer(cfg).anonymize(html)
        self.assertNotIn("Artagnan", out)
        other = '<a href="/message.php?cat=prive&dest=d%26%23039%3BArtagnan">x</a>'
        out = A.Anonymizer(A.Config()).anonymize(other)
        self.assertNotIn("Artagnan", out)
        self.assertEqual(A.Anonymizer(A.Config()).findings(out), [])

    def test_live_cookie_names_and_logout_token(self):
        html = ('Set-Cookie: md_passs=FAKE-passs-value; md_id=5550001\n'
                '<a href="/unlog.php?config=hardwarefr.inc&codehex=FAKE-codehex-value">out</a>')
        self.assertTrue(leaks(html))
        out = anon(html)
        for secret in ("FAKE-passs-value", "5550001", "FAKE-codehex-value"):
            self.assertNotIn(secret, out)
        self.assertIn("codehex=REDACTED", out)
        self.assertEqual(leaks(out), [])

    def test_operator_id_as_bare_number(self):
        cfg = A.Config(pseudos=[REAL1], profile_ids=[None, 1234567])
        html = '[quotemsg=2666649,1,1234567] <a href="/hfr/profil-1234567.htm">x</a> 112345678'
        self.assertTrue(A.Anonymizer(cfg).findings(html))
        out = A.Anonymizer(cfg).anonymize(html)
        self.assertIn("[quotemsg=2666649,1,900002]", out)
        self.assertIn("profil-900002.htm", out)
        self.assertIn("112345678", out)  # longer numbers are not touched
        self.assertEqual(A.Anonymizer(cfg).findings(out), [])

    def test_personal_profile_fields(self):
        html = ('<input type="text" name="email" value="me@example.org"><input type="text" name="custom_ville" value="Lyon">'
                '<select name="byear"><option value="1980">1980</option><option value="1985" selected="selected">1985</option></select>'
                '<select name="online"><option value="1" selected>yes</option></select>')
        self.assertTrue(leaks(html))
        out = anon(html)
        self.assertNotIn("Lyon", out)
        self.assertNotIn('value="1985" selected', out)
        self.assertIn('<option value="1" selected>', out)  # non-personal select kept
        self.assertEqual(leaks(out), [])

    def test_idempotent(self):
        html = '<b class="s2">%s</b><a href="/profil-4242.htm">x</a><input name="hash_check" value="abcdefabcdefabcdefabcdef">' % REAL1
        once = anon(html)
        self.assertEqual(anon(once), once)


class PrivateTests(unittest.TestCase):
    PAGE = ('<table class="messagetable"><tr><td><div id="para555"><p>secret words'
            '<div class="citation">nested <div>deep</div></div></p></div><div id="after">keep</div></td></tr></table>')

    def test_private_replaces_balanced_body(self):
        out = anon(self.PAGE, private=True)
        self.assertNotIn("secret words", out)
        self.assertNotIn("deep", out)
        self.assertIn(A.PRIVATE_PLACEHOLDER, out)
        self.assertIn('<div id="after">keep</div>', out)
        self.assertEqual(leaks(out, private=True), [])

    def test_without_flag_body_kept(self):
        self.assertIn("secret words", anon(self.PAGE))

    def test_check_private_flags_unreplaced_body(self):
        self.assertTrue(any("private" in r for _l, r, _e in leaks(self.PAGE, private=True)))


class CheckTests(unittest.TestCase):
    def reasons(self, html):
        return [r for _l, r, _e in leaks(html)]

    def test_clean_page_passes(self):
        clean = ('<b class="s2">user1</b><input name="hash_check" value="REDACTED">'
                 '<a class="%s">x</a>' % obf("md_cryptlink", "/forum2.php?cat=13&hash_check=REDACTED&pseudo=user2"))
        self.assertEqual(leaks(clean), [])

    def test_catches_real_pseudo(self):
        self.assertIn("real pseudo", self.reasons("<p>hello %s</p>" % REAL2.lower()))

    def test_catches_other_member_pseudo(self):
        self.assertIn("member pseudo not anonymized", self.reasons('<b class="s2">%s</b>' % OTHER))

    def test_catches_hash_check(self):
        self.assertIn("hash_check value not REDACTED", self.reasons("/x.php?hash_check=abcdef123456&p=1"))
        self.assertTrue(self.reasons('<input name="hash_check" value="abcdef123456">'))

    def test_catches_hash_check_in_obfuscated_url_with_line(self):
        page = "line1\nline2\n<a class=\"%s\">x</a>\n" % obf("md_noclass_cryptlink", "/a.php?hash_check=abcdef123456")
        found = leaks(page)
        self.assertEqual([(l, r) for l, r, _e in found],
                         [(3, "hash_check value not REDACTED (in obfuscated link)")])

    def test_catches_pseudo_in_obfuscated_url(self):
        page = '<a class="%s">x</a>' % obf("md_cryptlink", "/profil.php?pseudo=%s&x=1" % REAL1)
        self.assertTrue(any("obfuscated" in r for r in self.reasons(page)))

    def test_catches_cookie_email_ip_profile_id(self):
        self.assertTrue(any("cookie" in r for r in self.reasons("md_pass=hunter2hunter2")))
        self.assertIn("e-mail address", self.reasons("x@somewhere.example"))
        self.assertIn("operator e-mail", self.reasons("ME@EXAMPLE.ORG"))
        self.assertIn("IP address", self.reasons("from 198.51.100.7"))
        self.assertIn("operator profile id", self.reasons("/profil-4343.htm"))
        self.assertIn("hidden token input not REDACTED",
                      self.reasons('<input type="hidden" name="a" value="Ab12Cd34Ef56Gh78Ij90Kl12">'))


class CliTests(unittest.TestCase):
    def test_cli_end_to_end_and_check_exit_codes(self):
        import json
        with tempfile.TemporaryDirectory() as d:
            cfg = os.path.join(d, "local.json")
            with open(cfg, "w") as fh:
                json.dump({"pseudos": [REAL1], "emails": [], "profile_ids": []}, fh)
            src, dst = os.path.join(d, "in.html"), os.path.join(d, "out.html")
            with open(src, "w", encoding="latin-1") as fh:
                fh.write('<b class="s2">%s</b> é <input name="hash_check" value="abcdefabcdef">' % REAL1)
            self.assertEqual(A.main(["--config", cfg, src, dst]), 0)
            with open(dst, encoding="latin-1") as fh:
                self.assertEqual(fh.read(), '<b class="s2">user1</b> é <input name="hash_check" value="REDACTED">')
            self.assertEqual(A.main(["check", "--config", cfg, dst]), 0)
            self.assertNotEqual(A.main(["check", "--config", cfg, src]), 0)


if __name__ == "__main__":
    unittest.main()
