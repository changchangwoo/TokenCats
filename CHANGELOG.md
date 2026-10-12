# Changelog

All notable changes to TokenCats. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and
versions follow [Semantic Versioning](https://semver.org/). Each release's notes are also on the
[Releases](https://github.com/changchangwoo/TokenCats/releases) page and in the app's update window.

## [Unreleased]

## [0.1.4] - 2026-10-12

- Uses less power while the notch is closed: the session check and the full-screen detector no longer wake up every few seconds
- The first-run agents page keeps the `xcode-select --install` command on its own row, so it is never cut off
- README: what to do when a zip downloaded by hand is refused by Gatekeeper
- Under the hood: every strict-concurrency warning fixed, CI on every push, issue and pull request templates, a security policy and a changelog

## [0.1.3] - 2026-10-11

- TokenCats now updates itself: once a day it looks for a new version and asks before installing. Settings › About
  has the switch; "Check for Updates…" is in the menu bar menu
- This is the last version you install by hand: `brew upgrade --cask tokencats`

## [0.1.2] - 2026-10-11

- The closed notch now shows only the cats in your room. The session alert dots, the +N count and tap-to-jump are
  gone, so the notch and your agent sessions are fully separate
- Battery saver is off by default, so a fresh install runs at full speed on battery. While battery saver is on and
  slowing the room, a "Power saving" badge shows in the room's corner
- First-run setup: the GitHub card keeps its place while it loads, every page lines up at the same height, notices
  no longer push the buttons around, and the card options now redraw the preview

## [0.1.1] - 2026-10-11

- First-run setup now walks you through connecting Claude Code and Codex, Claude limits, the GitHub profile card
  and launch at login (Settings › General › Show first-run setup again to revisit)
- The profile card on your README links back to TokenCats
- README: install and privacy notes

## [0.1.0] - 2026-10-11

First public release. Cats in your MacBook notch that grow on the tokens you spend in Claude Code and Codex, with a
GitHub profile card.

[Unreleased]: https://github.com/changchangwoo/TokenCats/compare/v0.1.4...HEAD
[0.1.4]: https://github.com/changchangwoo/TokenCats/releases/tag/v0.1.4
[0.1.3]: https://github.com/changchangwoo/TokenCats/releases/tag/v0.1.3
[0.1.2]: https://github.com/changchangwoo/TokenCats/releases/tag/v0.1.2
[0.1.1]: https://github.com/changchangwoo/TokenCats/releases/tag/v0.1.1
[0.1.0]: https://github.com/changchangwoo/TokenCats/releases/tag/v0.1.0
