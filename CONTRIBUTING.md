# Contributing

## Getting started

```bash
git clone https://github.com/changchangwoo/TokenCats.git && cd TokenCats
swift test                        # Core tests. Runs with Command Line Tools alone, no Xcode needed (see scripts/test.sh)
open app/TokenCats.xcodeproj      # The app builds in Xcode. Scheme: TokenCats
scripts/build-app.sh && scripts/run-app.sh
```

## Working rules

- **Core is test-first.** When you change a rule (ledger, store, room layout, card, preference defaults), write a
  failing test and make it pass. Core does not import SwiftUI, AppKit or Defaults.
- **UI is checked with snapshots.** When you touch a screen, capture before and after with `scripts/snapshot.sh` and
  compare them with `scripts/compare-snapshots.py`. Only the intended change may differ. Card SVGs are byte-identical
  unless the renderer itself changed.
- **One type per file.** A file is named after the main type inside it. Screens live in `Features/<screen>/`, rules in
  `Core/<area>/`.
- **Settings live in one place.** Add a new setting to `AppSettings.Key` and `PreferenceDefaults`; never write a literal
  default in a view.
- **Keep NotchShell edits minimal.** Code that came from boring.notch is changed only as far as behaviour requires.
  TokenCats rules do not go in there.
- **English keys in code, Korean in the catalog.** Views use English literals such as `Text("Store")`. Korean goes in
  `Resources/l10n/<area>.json` as `"Store": "상점"`, and `python3 scripts/build-string-catalog.py` generates
  `Localizable.xcstrings` from it (never edit the catalog by hand). Sentences with variables, and states or return
  values that are shown to people, are `LocalizedStringResource` rather than `String`, so they follow a language
  change. Core never builds human-readable sentences; it returns enums and values. `python3 scripts/check-strings.py`
  catches Korean literals in source and missing translations.

## Commits

`type: summary` ([Conventional Commits](https://www.conventionalcommits.org/)), written in English. `type` is one of
feat · fix · refactor · docs · chore · test · art. One commit carries one change; the body says why, and how it was
verified (test count, snapshot result).

## Before a PR

1. `swift test` passes in full
2. The Debug build succeeds (`scripts/snapshot.sh /tmp/snap` builds it for you)
3. `python3 scripts/check-strings.py` prints `strings ok`
4. If you changed a screen, put the snapshot comparison in the PR. If you changed copy, also check that Korean
   snapshots taken with `TOKENCATS_LAUNCH_ARGS="-companionLanguage ko"` are unchanged
5. New cats, themes, agents and languages follow the extension points in [ARCHITECTURE.md](ARCHITECTURE.md)
