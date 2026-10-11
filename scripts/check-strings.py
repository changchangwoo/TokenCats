#!/usr/bin/env python3
"""Fails when the code or the string catalog breaks the localization rules.

1. No Korean (Hangul) in string literals under app/**/*.swift: UI text is an English key, Korean lives in the
   catalog. Comments are ignored. Interpolated literals count ("\\(n)일" is a literal too).
2. Every key in app/TokenCats/Resources/Localizable.xcstrings has a translation in every target language
   (plural keys need the variant). Keys Xcode discovered on its own without one are reported here.

Usage: python3 scripts/check-strings.py   (exit code 1 on any finding)
"""
import json, pathlib, re, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SOURCES = ROOT / "app"
CATALOG = ROOT / "app/TokenCats/Resources/Localizable.xcstrings"
TARGETS = ["ko"]
HANGUL = re.compile(r'"(?:[^"\\\n]|\\.)*[가-힣](?:[^"\\\n]|\\.)*"')


def strip_comments(text):
    # Line comments only; the code base has no block comments with strings worth checking.
    return "\n".join(re.sub(r'(^|\s)//.*$', r'\1', line) for line in text.split("\n"))


def hangul_literals():
    findings = []
    for path in sorted(SOURCES.rglob("*.swift")):
        for number, line in enumerate(strip_comments(path.read_text()).split("\n"), 1):
            for match in HANGUL.finditer(line):
                findings.append(f"{path.relative_to(ROOT)}:{number}: {match.group(0)}")
    return findings


def missing_translations():
    catalog = json.loads(CATALOG.read_text())
    findings = []
    for key, entry in catalog["strings"].items():
        localizations = entry.get("localizations", {})
        for language in TARGETS:
            unit = localizations.get(language)
            if unit is None:
                findings.append(f"'{key}' has no {language} translation")
            elif "stringUnit" in unit and unit["stringUnit"].get("state") != "translated":
                findings.append(f"'{key}' {language} is {unit['stringUnit'].get('state')}")
    return findings


def main():
    findings = hangul_literals() + missing_translations()
    for finding in findings:
        print(finding)
    print(f"{len(findings)} finding(s)" if findings else "strings ok")
    sys.exit(1 if findings else 0)


if __name__ == "__main__":
    main()
