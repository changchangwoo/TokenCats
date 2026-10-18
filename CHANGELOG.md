# Changelog

All notable changes to TokenCats. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and
versions follow [Semantic Versioning](https://semver.org/). Each release's notes are also on the
[Releases](https://github.com/changchangwoo/TokenCats/releases) page and in the app's update window.

## [Unreleased]

## [0.1.7] - 2026-10-18

- Home shows Claude Code's service status under the usage limits. When a Claude request fails with a server or overload error, TokenCats checks Claude's public status page (at most every five minutes, with no session details), turns the row red, explains any reported incident and can send a macOS notification. Connected hooks pick up the new failure event when the app starts, for Claude sessions opened after that
- The Codex tab shows OpenAI's published Codex Desktop status in the same row, and a newly reported issue can send a notification too
- When Claude Code's `/usage` reports a separate Fable weekly limit, Home shows it beside the 5-hour and weekly limits (read at most every 15 minutes while Home is open)
- Statistics is now a card dashboard: today, the last 7 days and your streak on top, the week's tokens stacked by Claude and Codex, and the year graph below
- Every cat now has the same black outline as the black cat, with stray pixels cleaned up
- Update notes like these now come in Korean on Macs set to Korean
- README: new Statistics screenshot, notch GIF and cat portraits

## [0.1.6] - 2026-10-13

- Three daily missions on Home — check in, pet a cat, use 1M tokens — each paying a small churu bonus when you tap Claim. The usage streak multiplies the rewards, up to 2× from ten days. Unclaimed rewards expire at midnight. Settings › Home display can hide the section
- Every cat has a bond level, 1 to 99. It rises when you pet the cat, give it churu (right-click a cat in the room or the collection, 1M churu), and while the app runs with the cat in the room. Hover a cat to see its level and bar. Settings › GitHub profile can put each cat's level on the profile card (off by default)
- Give a cat its own name: right-click it in the collection and type inside the notch. Up to 16 characters, and a blank name brings back the coat name
- Two new cats in the adoption box: the Sphynx (Rare) and the Norwegian (Unique). The tier odds are unchanged, so each cat in those tiers is now half as likely
- Fresh art for every cat's walk, and for the sitting and grooming poses of every coat except the black cat
- The 365-day graph in Statistics fits its panel instead of cutting off the newest weeks

## [0.1.5] - 2026-10-12

- Fixes a launch failure in 0.1.3 and 0.1.4: installed through Homebrew, the app quit the moment it started, because the release build's hardened runtime refused the ad-hoc signed update framework. The release build no longer uses the hardened runtime (it only matters for notarization), and every build now launches itself once before it ships
- If you have 0.1.3 or 0.1.4, run `brew upgrade --cask tokencats`: a build that does not start cannot update itself

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

[Unreleased]: https://github.com/changchangwoo/TokenCats/compare/v0.1.7...HEAD
[0.1.7]: https://github.com/changchangwoo/TokenCats/releases/tag/v0.1.7
[0.1.6]: https://github.com/changchangwoo/TokenCats/releases/tag/v0.1.6
[0.1.5]: https://github.com/changchangwoo/TokenCats/releases/tag/v0.1.5
[0.1.4]: https://github.com/changchangwoo/TokenCats/releases/tag/v0.1.4
[0.1.3]: https://github.com/changchangwoo/TokenCats/releases/tag/v0.1.3
[0.1.2]: https://github.com/changchangwoo/TokenCats/releases/tag/v0.1.2
[0.1.1]: https://github.com/changchangwoo/TokenCats/releases/tag/v0.1.1
[0.1.0]: https://github.com/changchangwoo/TokenCats/releases/tag/v0.1.0
