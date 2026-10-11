# GitHub App 등록 (장치 인증용, 한 번만)

> 등록 완료 (2026-10-11): 앱 이름 `tokenCatsApp`, slug `tokencatsapp`, 설정 화면 https://github.com/settings/apps/tokencatsapp.
> `TokenCats`는 같은 이름의 GitHub 계정(@tokencats)이 있어 쓸 수 없었다. Client ID와 slug는 `app/TokenCats/Info.plist`의
> `NCGitHubAppClientID`, `NCGitHubAppSlug`에 들어 있다.

`gh` CLI가 없는 사용자도 "GitHub 코드로 연결"을 쓸 수 있게 하려면 GitHub App을 한 번 등록하고 client ID를 앱에 넣는다. 등록 전에는 이 버튼이 보이지 않고 `gh` 로그인 연결만 동작한다.

## 1. 앱 만들기

github.com → Settings → Developer settings → GitHub Apps → **New GitHub App**

| 항목 | 값 |
|---|---|
| GitHub App name | `tokenCatsApp` (전역에서 유일해야 하고, 기존 계정 이름과도 겹치면 안 됨) |
| Homepage URL | 프로젝트 저장소 주소 |
| Callback URL | 비워 둠 |
| **Expire user authorization tokens** | **끔** (갱신에는 client secret이 필요해 데스크톱 앱에서 쓸 수 없다) |
| Request user authorization (OAuth) during installation | 끔 |
| **Enable Device Flow** | **켬** |
| Webhook → Active | 끔 |
| Repository permissions → **Contents** | **Read and write** |
| Repository permissions → Metadata | Read-only (자동) |
| Where can this GitHub App be installed? | Any account |

만든 뒤 화면의 **Client ID**(`Iv23…`)를 복사한다. Client secret은 만들지 않는다.

## 2. 앱에 client ID 넣기

둘 중 하나:

- 배포용: `app/TokenCats/Info.plist`에 `NCGitHubAppClientID`(client ID)와 `NCGitHubAppSlug`(앱 주소의 slug) 키로 넣는다.
- 시험용: `defaults write <앱 번들 ID> githubAppClientID Iv23...`

## 3. 사용자가 하는 일

1. 설정 › GitHub 프로필 › GitHub 프로필 자동 갱신 → **GitHub 코드로 연결**
2. 브라우저에 뜬 github.com/login/device에 앱에 보이는 8자리 코드를 입력하고 승인한다.
3. 앱이 프로필 레포에 아직 설치되지 않았으면 TokenCats가 설치 화면(`github.com/apps/<slug>/installations/new`)을 연다. 거기서 **Only select repositories → 프로필 레포(`아이디/아이디`)** 를 고른다. 사용자 토큰은 앱이 설치된 레포에서만 동작하므로, 앱은 다른 레포에 쓸 수 없다.

## 시험용 대상 레포

실제 프로필 레포 대신 다른 레포로 시험하려면:

```
defaults write <앱 번들 ID> profileRepoOverride owner/repo
```
