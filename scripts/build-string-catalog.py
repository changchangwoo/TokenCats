#!/usr/bin/env python3
"""Builds app/TokenCats/Resources/Localizable.xcstrings from the translation fragments in Resources/l10n/*.json.

Each fragment maps an English key (the literal in the code) to its Korean text:

    { "Store": "상점", "%lld days": "%lld일", "%lld days|one": "%lld day" }

A key with a "<key>|one" entry gets English plural variants: `other` is the key itself and `one` is that entry
(the key must carry a %lld). Korean has no plural, so its value is a plain string.
Every key is marked `manual` so Xcode never prunes it; keys Xcode discovers on its own land without a `ko`
translation, which scripts/check-strings.py reports.
"""
import json, pathlib, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent / "app/TokenCats/Resources"
FRAGMENTS = ROOT / "l10n"
CATALOG = ROOT / "Localizable.xcstrings"
SOURCE, TARGETS = "en", ["ko"]


def unit(value):
    return {"stringUnit": {"state": "translated", "value": value}}


def main():
    keys = {}
    for path in sorted(FRAGMENTS.glob("*.json")):
        for key, value in json.loads(path.read_text()).items():
            base, _, form = key.partition("|")
            entry = keys.setdefault(base, {"ko": None, "one": None})
            if form == "one":
                entry["one"] = value
            elif form:
                sys.exit(f"{path.name}: unknown form '{form}' in '{key}'")
            elif entry["ko"] is not None and entry["ko"] != value:
                sys.exit(f"{path.name}: '{base}' already translated as '{entry['ko']}'")
            else:
                entry["ko"] = value
    strings = {}
    for key, entry in sorted(keys.items()):
        if entry["ko"] is None:
            sys.exit(f"'{key}' has no Korean text")
        localizations = {"ko": unit(entry["ko"])}
        if entry["one"] is not None:
            if "%lld" not in key:
                sys.exit(f"'{key}|one' given but the key has no %lld")
            localizations["en"] = {"variations": {"plural": {"one": unit(entry["one"]), "other": unit(key)}}}
        strings[key] = {"extractionState": "manual", "localizations": localizations}
    catalog = {"sourceLanguage": SOURCE, "strings": strings, "version": "1.0"}
    CATALOG.write_text(json.dumps(catalog, ensure_ascii=False, indent=2, sort_keys=True) + "\n")
    print(f"{len(strings)} keys → {CATALOG.relative_to(ROOT.parent.parent.parent)}")


if __name__ == "__main__":
    main()
