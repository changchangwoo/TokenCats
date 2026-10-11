# Notices

TokenCats is distributed under GPL-3.0 (see `LICENSE`). Its notch window is built on boring.notch;
TokenCats is not affiliated with or endorsed by TheBoredTeam.

- `app/TokenCats/NotchShell/`, the settings window (`Features/Settings/SettingsView.swift`,
  `SettingsWindowController.swift`, `NotchSettings.swift`, `AboutSettings.swift`) and the Xcode project — boring.notch by TheBoredTeam,
  https://github.com/TheBoredTeam/boring.notch, commit e2654ee41b0b9aee72c5a8113a11ab855896d6e6, GPL-3.0. Modified:
  the media player, calendar, mirror, shelf, HUD, battery HUD, XPC helper, Sparkle updater, accent-colour
  settings and the welcome screen artwork were removed.
  boring.notch itself credits DynamicNotchKit (MIT, Kai Azim) and Parrot (MPL-2.0, Aditya Vaidyam); their license
  texts are in `THIRD_PARTY_LICENSES`.
- `app/TokenCats/Core/Agents/SocketServer.swift` and the hook-script pattern in
  `app/TokenCats/Resources/tokencats-hook.py` — adapted from Notchi by sk-ruban,
  https://github.com/sk-ruban/notchi, commit e6f8b8a805cec31b5d3844d2ea8faa7a836ebc7e, GPL-3.0.
- UX references only (no code copied): Claude Island / Vibe Notch (farouqaldori), Buddi.
- Cat and room art is drawn for this project. A folder at `~/Library/Application Support/TokenCats/art/` may
  override the bundled cat art for local experiments (`CatSprites.artDirectory`).
- Profile card font: Baloo 2 by The Baloo 2 Project Authors, https://github.com/EkType/Baloo2, SIL Open Font
  License 1.1 (`app/TokenCats/Resources/Fonts/Baloo2-OFL.txt`). Subset and embedded by `scripts/build-card-font.sh`
  into `Core/Card/CardFont.swift`.
