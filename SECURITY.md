# Security

TokenCats runs on your Mac with your user's rights, reads the usage logs of Claude Code and Codex, can write one
hook line into their settings files, and can talk to GitHub with a token you grant it. That makes it worth
reporting problems carefully.

## Reporting a vulnerability

Please do not open a public issue for a security problem. Use GitHub's private reporting instead:

**https://github.com/changchangwoo/TokenCats/security/advisories/new**

Say what the problem is, how to reproduce it, and which version you saw it in (Settings › About). You should hear
back within a week. Once a fix ships, the advisory is published with credit to you unless you ask otherwise.

## What is in scope

- Anything that lets another process or user read the GitHub token (`github-token.json`, 0600 in the data folder)
  or the data folder's contents.
- The hook script (`tokencats-hook.py`) and the status line script: they run inside your agent's environment. Any
  way to make them run other code, or leak prompt contents, is in scope.
- The socket the app listens on for hook events, and the settings-file edits the app makes.
- The update path: Sparkle verifies updates with the EdDSA key in `Info.plist`; anything that gets an unsigned
  update installed is in scope.
- The profile card upload: it must only ever touch the marked section of your profile README.

## Supported versions

Only the latest release gets fixes. The app updates itself (Settings › About), and Homebrew users can run
`brew upgrade --cask tokencats`.
