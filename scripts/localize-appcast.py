#!/usr/bin/env python3
"""Adds a translation of the release notes to the appcast that generate_appcast wrote.

generate_appcast embeds one <description> (the English notes) in the item. Sparkle chooses among several
<description> elements by their xml:lang and the Mac's preferred languages, so the existing one is marked English
and the translation goes right after it. A Mac in any other language keeps the English notes.

Refuses a signed feed (the edit would break the signature) and an item without exactly one <description>.

Usage: python3 scripts/localize-appcast.py appcast.xml <language> <notes.html>
"""
import pathlib, re, sys

DESCRIPTION = re.compile(r"(?P<indent>[ \t]*)<description>(?P<body><!\[CDATA\[.*?\]\]>)</description>", re.S)


def localize(feed, language, notes):
    if "sparkle-signatures:" in feed:
        sys.exit("error: the appcast is signed; adding notes would break its signature")
    if "]]>" in notes:
        sys.exit("error: the notes contain ']]>', which would end the CDATA section early")
    found = list(DESCRIPTION.finditer(feed))
    if len(found) != 1:
        sys.exit(f"error: expected one <description> in the appcast, found {len(found)}")
    match = found[0]
    indent = match.group("indent")
    localized = (f'{indent}<description xml:lang="en">{match.group("body")}</description>\n'
                 f'{indent}<description xml:lang="{language}"><![CDATA[{notes.strip()}\n]]></description>')
    return feed[:match.start()] + localized + feed[match.end():]


if __name__ == "__main__":
    if len(sys.argv) != 4:
        sys.exit(__doc__.strip().splitlines()[-1])
    path, language, notes_path = pathlib.Path(sys.argv[1]), sys.argv[2], pathlib.Path(sys.argv[3])
    path.write_text(localize(path.read_text(encoding="utf-8"), language, notes_path.read_text(encoding="utf-8")),
                    encoding="utf-8")
