# GitHub App registration (for device authorization, once)

> Registered on 2026-10-11: app name `tokenCatsApp`, slug `tokencatsapp`, settings page
> https://github.com/settings/apps/tokencatsapp. `TokenCats` was unavailable because a GitHub account of that name
> (@tokencats) exists. The client ID and slug are in `NCGitHubAppClientID` and `NCGitHubAppSlug` in
> `app/TokenCats/Info.plist`.

For users without the `gh` CLI to use "Connect with a GitHub code", a GitHub App is registered once and its client ID
is put into the app. Before registration that button is hidden and only the `gh` login connection works.

## 1. Create the app

github.com → Settings → Developer settings → GitHub Apps → **New GitHub App**

| Field | Value |
|---|---|
| GitHub App name | `tokenCatsApp` (globally unique, and must not collide with an existing account name) |
| Homepage URL | The project repository URL |
| Callback URL | Leave empty |
| **Expire user authorization tokens** | **Off** (refreshing needs the client secret, which a desktop app cannot hold) |
| Request user authorization (OAuth) during installation | Off |
| **Enable Device Flow** | **On** |
| Webhook → Active | Off |
| Repository permissions → **Contents** | **Read and write** |
| Repository permissions → Metadata | Read-only (automatic) |
| Where can this GitHub App be installed? | Any account |

After creating it, copy the **Client ID** (`Iv23…`) from the page. Do not create a client secret.

## 2. Put the client ID into the app

One of the two:

- For distribution: add the `NCGitHubAppClientID` (client ID) and `NCGitHubAppSlug` (the slug in the app's URL) keys to
  `app/TokenCats/Info.plist`.
- For testing: `defaults write <app bundle ID> githubAppClientID Iv23...`

## 3. What the user does

1. Settings › GitHub profile › Auto-update GitHub profile → **Connect with a GitHub code**
2. Enter the 8-character code shown in the app at github.com/login/device in the browser and approve.
3. If the app is not yet installed on the profile repository, TokenCats opens the installation page
   (`github.com/apps/<slug>/installations/new`). There, choose **Only select repositories → the profile repository
   (`username/username`)**. The user token only works on repositories where the app is installed, so the app cannot
   write anywhere else.

## Test target repository

To test against a repository other than the real profile repository:

```
defaults write <app bundle ID> profileRepoOverride owner/repo
```
