# Release

TokenCats ships without an Apple developer account. The app is ad-hoc signed and not notarized, and it is installed
through a Homebrew tap (`changchangwoo/homebrew-tap`).

## Building

```bash
scripts/package-release.sh
```

- `build/release/TokenCats-<version>.zip`: universal (Apple Silicon and Intel), ad-hoc signed. It is zipped with
  `ditto`, so the bundle's signature survives intact.
- `build/release/tokencats.rb`: the cask, which is `packaging/homebrew/tokencats.rb.template` with the version and
  sha256 filled in.
- The script uploads nothing. The commands it prints at the end create the GitHub Release and put the cask at
  `Casks/tokencats.rb` in the tap.
- The repository must be public for release files to be downloaded anonymously.

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
