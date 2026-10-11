# Release

TokenCats ships without an Apple developer account. The app is ad-hoc signed and not notarized, and it is installed
through a Homebrew tap (`changchangwoo/homebrew-tap`).

## Building

```bash
scripts/package-release.sh release-notes.md
```

- `build/release/TokenCats-<version>.zip`: universal (Apple Silicon and Intel), ad-hoc signed. It is zipped with
  `ditto`, so the bundle's signature survives intact.
- `build/release/tokencats.rb`: the cask, which is `packaging/homebrew/tokencats.rb.template` with the version and
  sha256 filled in.
- `appcast.xml` at the repository root: the Sparkle feed, with the zip's EdDSA signature and the release notes from
  the "- " lines of the notes file. Commit it with the release; the app reads it from `main`.
- The script uploads nothing. The commands it prints at the end create the GitHub Release and put the cask at
  `Casks/tokencats.rb` in the tap.
- The repository must be public for release files to be downloaded anonymously.

## Releasing, in order

1. Bump `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `app/TokenCats.xcodeproj/project.pbxproj`.
2. `scripts/package-release.sh notes.md`, then commit `appcast.xml` with the bump as `chore(release): x.y.z`.
3. Push `main` first (the feed must point at a zip that is about to exist), then
   `gh release create vx.y.z build/release/TokenCats-x.y.z.zip --title "TokenCats x.y.z"`.
4. Copy `build/release/tokencats.rb` to the tap's `Casks/tokencats.rb` and push.

## In-app updates (Sparkle)

- The app embeds [Sparkle 2](https://sparkle-project.org). Once a day it reads `appcast.xml` from `main`
  (`SUFeedURL` in `Info.plist`) and, when a newer version is listed, asks before downloading and installing it.
  Settings › About has the switch and a manual check, as does the menu bar menu.
- Because the app is not notarized, the update's trust comes from the EdDSA signature in the feed, checked against
  `SUPublicEDKey` in `Info.plist`. Sparkle releases the downloaded update from quarantine itself.
- The private key lives in the login keychain of the Mac that releases (`generate_keys` from the Sparkle package
  put it there). An exported copy is kept outside the repository; never commit it. A Mac without the key cannot
  produce a feed the shipped app accepts.
- The cask says `auto_updates true`, so `brew upgrade` leaves the app alone once Sparkle has updated it
  (`brew upgrade --greedy` still reinstalls from the cask).

## Why the cask looks the way it does

- **Quarantine removal (`postflight_steps`)**: Homebrew puts the quarantine attribute on downloaded apps. Gatekeeper
  blocks an un-notarized app that still carries it, so the install step removes the quarantine from TokenCats.app
  alone. `postflight do` prints a deprecation warning, hence `postflight_steps`.
- **Install by full name**: Homebrew 7 refuses the short name (`tokencats`) for a tap it has not seen. The README spells
  it `changchangwoo/tap/tokencats`.
- **zip**: no mount step, and a format that has been verified.
- **`uninstall quit`, `zap`**: quits the app before removal, and `--zap` deletes the paths only TokenCats uses (the data
  folder, preferences, `~/.tokencats`). Hooks and the status line in `~/.claude` and `~/.codex` are removed only by
  disconnecting in the app.
- The `signer changed` warning Homebrew shows on upgrade is because ad-hoc signatures differ from build to build; it
  has no effect on behaviour.

## Signing and where things are stored

- An ad-hoc signature's code hash (cdhash) changes with every build, so a new version cannot read what the previous one
  stored in the login keychain. That is why the GitHub device-authorization token lives in `github-token.json` (0600)
  in the data folder rather than the keychain. This is the same approach the `gh` CLI takes, and the file is excluded
  from backups.
- Launch at login (`SMAppService.mainApp`) survives switching to a new build.
