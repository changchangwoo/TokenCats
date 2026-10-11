# 릴리스

TokenCats는 Apple 개발자 계정 없이 배포합니다. 앱은 ad-hoc 서명이고 공증하지 않으며, Homebrew tap(`changchangwoo/homebrew-tap`)으로 설치합니다.

## 만들기

```bash
scripts/package-release.sh
```

- `build/release/TokenCats-<버전>.zip`: Apple Silicon·Intel 범용, ad-hoc 서명. 압축은 `ditto`로 해서 번들의 서명이 그대로 유지됩니다.
- `build/release/tokencats.rb`: `packaging/homebrew/tokencats.rb.template`에 버전과 sha256을 채운 cask.
- 스크립트는 아무것도 올리지 않습니다. 끝에 출력하는 명령으로 GitHub Release를 만들고, cask를 tap의 `Casks/tokencats.rb`로 올립니다.
- 릴리스 파일을 익명으로 받으려면 저장소가 공개여야 합니다.

## cask가 이렇게 생긴 이유

- **quarantine 제거(`postflight_steps`)**: Homebrew는 내려받은 앱에 quarantine을 붙입니다. 공증하지 않은 앱은 그대로면 Gatekeeper가 막으므로, 설치 단계에서 TokenCats.app 하나의 quarantine만 지웁니다. `postflight do`는 사용 중단 경고가 나서 `postflight_steps`를 씁니다.
- **전체 이름으로 설치**: Homebrew 7은 처음 보는 tap의 짧은 이름(`tokencats`)을 거부합니다. README에는 `changchangwoo/tap/tokencats`로 적습니다.
- **zip**: 마운트 단계가 없고 검증한 형식입니다.
- **`uninstall quit`, `zap`**: 지우기 전에 앱을 끄고, `--zap`이면 TokenCats만 쓰는 경로(데이터 폴더, 환경설정, `~/.tokencats`)를 지웁니다. `~/.claude`, `~/.codex`의 훅·상태줄은 앱의 연결 해제로만 지웁니다.
- 업그레이드 때 Homebrew가 `signer changed` 경고를 보여 주는 것은 ad-hoc 서명이 빌드마다 달라서이고, 동작에는 영향이 없습니다.

## 서명과 저장 위치

- ad-hoc 서명은 빌드마다 서명 해시(cdhash)가 바뀌어, 앞 버전이 로그인 키체인에 저장한 항목을 새 버전이 읽지 못합니다. 그래서 GitHub 기기 인증 토큰은 키체인이 아니라 데이터 폴더의 `github-token.json`(0600)에 둡니다. `gh` CLI와 같은 방식이고, 이 파일은 백업에 들어가지 않습니다.
- 로그인 시 실행(`SMAppService.mainApp`)은 새 빌드로 바꿔도 유지됩니다.
