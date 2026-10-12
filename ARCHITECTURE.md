# TokenCats architecture

## Three layers

```
app/TokenCats/
  Core/        Rules and data. SwiftPM target TokenCatsCore. No UI; this is what the tests cover.
  Features/    Screens. One folder per screen (Home · Cats · Store · ClosedNotch · Profile · Settings · Shared).
  NotchShell/  The notch window taken from boring.notch: open/close, gestures, sizing, animation, welcome screen.
  App/         Entry point (TokenCatsApp) and the menu bar.
  Resources/   JSON catalogs, cat and room art (build output), fonts, hook scripts.
Tests/TokenCatsCoreTests/   Mirrors the Core folder structure.
art-src/      Art sources. Cat and room art is edited here only (art-src/README.md).
```

Dependencies point **Features → Core**; **NotchShell** opens the window and hosts the Features screens. Features reads
only two pieces of NotchShell window state (`NotchCoordinator`: open tab and display, `BatteryStatusViewModel`:
battery). Core imports only `Foundation`, `Combine`, `Darwin` and `os.log`, and knows nothing of SwiftUI, AppKit or
`Defaults`. That is why `swift test` runs without Xcode, and why every rule — card, ledger, room layout — is pinned by
a test.

`NotchShell` means borrowed code. Every file carries a provenance comment and is changed as little as it takes to
work. TokenCats rules that have nothing to do with the notch must not end up in there. The one exception is
`FullscreenDetector`, which does in-house what boring.notch did through an external package: detect full-screen apps
(the closed notch and its cats hide over a full-screen app).

## Data flow

```
Agent logs (~/.claude, ~/.codex)
   └─ TokenUsageReader · DailyTokenScan  ─┐
Hook script → SocketServer → AgentHub      │   (session notices only; unrelated to churu)
                                           ▼
                         ChuruLedger → ChuruModel (balance · today · streak · missions)
                                           │
                     StoreService ─ purchase ─▶ CatHousehold · StoreInventory (cats.json · inventory.json)
                                           │
                   CatRoomScene · CatRoomMotion ─▶ CatRoomView (room in the notch) / ClosedNotchView (closed notch)
                                           │
                      CatRoomSVG · ContributionYear ─▶ ProfileCard ─▶ ProfileSync ─▶ GitHub README
```

- Every data file name lives in one place, `Core/Support/DataFiles.swift`. `Backup` backs up, restores and resets from
  that list.
- Preference keys and defaults live only in `Features/Settings/AppSettings.swift` (keys) and
  `Core/Settings/Preferences.swift` (defaults). Views read them only through the
  `@AppStorage(AppSettings.Key.x) private var x = AppSettings.Default.x` pattern.
- Paths come from `AppPaths`. In Debug builds the `NC_SUPPORT_DIR` environment variable redirects the data folder, so
  snapshots and tests work on a fixed copy (Release ignores it: the hook script's socket path is fixed, and the two
  must never diverge).

## App-lifetime state

`StoreModel`, `ChuruModel`, `CostUsageModel`, `UsageLimitsModel`, `HomeUsageHistoryModel`, `UIDisplayModel`,
`ProfileSync`, `CatSprites` and `CatRoomStage` are `.shared` singletons, because the notch window may be open on
several displays while the data must stay single.

Rules:
- Views reach them only through `@ObservedObject`, and singletons never read each other's UserDefaults directly; they go
  through `AppSettings`.
- State changes are made by Core types such as `StoreService` and `ChuruTracker`; a singleton only publishes the result
  on the main thread.
- Core has exactly two singletons, `SocketServer` and `AgentHub`, and both are process-lifetime services.

## Extension points

### Adding a cat
Put the four per-action pictures (two walks, idle, groom; petting comes from groom and the small portrait from idle)
in `art-src/cats/<new coat>/` and run `swift scripts/build-cat-art.swift`; that creates the coat. What goes in which
file is in [art-src/README.md](art-src/README.md). Add the coat to an adoption-box tier in
`Resources/store-catalog.json` and it shows up in the store. `CatAssetCatalogTests` checks every coat's size, floor
line and seams, and that the app resources are identical to the source folder.

### Adding a room theme
Put the wall and floor sources in `art-src/rooms/<theme>/` and run `scripts/import-room-art.swift` to produce the 1x
and 2x PNGs in `Resources/RoomArt/`. Add the theme (colours, identifier) to `Resources/room-themes.json` and its price
to `store-catalog.json`. `RoomThemeTests` checks that the catalog and the picture files agree and that the card preview
has enough contrast.

### Adding an agent
Add a case to `Core/Agents/AgentIntegration.swift` that answers the settings-file path and the hook events.
`Resources/tokencats-hook.py` puts the provider name it receives as its first argument into the socket message, so if
the event names differ, update that script's branches together with the state mapping in `AgentSession`. For token
counting, add the log format to `TokenUsageReader`.

### Adding a language
Add that language's column to `Resources/Localizable.xcstrings` and you are done. The language list in Settings is
built by `AppLanguage` from the languages in the bundle (`Bundle.main.localizations`), with each name shown in its own
language. No code changes. To manage a language through translation fragments (`Resources/l10n/*.json`) the way Korean
is, add its code to `TARGETS` in `scripts/build-string-catalog.py`. Language flows through a single
`environment(\.locale)` that `.localized()` applies at the four root views (notch, settings, onboarding, menu bar), so
picking it in Settings takes effect without a relaunch. The profile card SVG is seen worldwide and is always English.

## Tests and verification

- Core uses Swift Testing (`swift test`). A new rule starts with a failing test.
- UI is a Debug build plus snapshots. `scripts/snapshot.sh <dir>` writes the five card SVGs and the screen PNGs, and
  `scripts/compare-snapshots.py <base> <new>` compares them byte by byte and pixel by pixel. Cards must be
  byte-identical. Add app arguments such as `TOKENCATS_LAUNCH_ARGS="-companionLanguage en"` to capture per language.
- Copy is checked with `python3 scripts/check-strings.py`, which catches Korean literals in source and missing
  translations in the catalog.

## Names and former names

Every identifier that touches the disk uses the TokenCats name. For users who installed in the "Notch Companion"
days, `LegacyDataMigration` (App) and `IdentityMigration` (Core) move things once on first launch. The former names
exist only in `Core/Support/LegacyIdentity.swift`, and the hook, status line and README block also recognise the old
markers as ours.

| Identifier | Current value | Former value (migrated) |
|---|---|---|
| `.app` name (`PRODUCT_NAME`) | `TokenCats` | `Notch Companion` |
| Bundle ID | `io.github.changchangwoo.tokencats` | `com.changwoo.notchcompanion` (preferences copied, `SU*` excluded) |
| Data folder | `~/Library/Application Support/TokenCats/` | `.../NotchCompanion/` (moved whole) |
| Socket | `<data folder>/companion.sock`, or `~/.tokencats/` when the path is too long | |
| Hook and status-line scripts | `tokencats-hook.py`, `tokencats-statusline.py` | `notch-companion-*.py` (commands rewritten to the new path) |
| Settings-file backups | `*.tokencats.bak`, `*.tokencats-statusline.bak` | The first status-line backup is renamed |
| README markers | `<!-- tokencats:start -->` … `<!-- tokencats:end -->` | Still recognised; replaced by the new markers on the next README write |
| Keychain | service `TokenCats.github` | Not migrated (device flow was never enabled, so no token was stored) |
| UserDefaults keys | `companion*`, `profile*`, `roomThemeID` and so on (`AppSettings.Key`) | Key names unchanged |
