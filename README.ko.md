<p align="center">
  <img src="app/TokenCats/Assets.xcassets/AppIcon.appiconset/icon_128x128@2x.png" width="96" alt="TokenCats">
</p>

<h1 align="center">TokenCats</h1>

<p align="center">
  <a href="https://github.com/changchangwoo/TokenCats/actions/workflows/ci.yml"><img src="https://github.com/changchangwoo/TokenCats/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <img src="https://img.shields.io/badge/macOS-14+-2F6FDE?logo=apple&logoColor=white" alt="macOS 14+">
  <img src="https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white" alt="Swift 6">
  <img src="https://img.shields.io/badge/Apple%20Silicon%20%C2%B7%20Intel-universal-555555" alt="Apple Silicon · Intel">
  <img src="https://img.shields.io/badge/Claude%20Code%20%C2%B7%20Codex-supported-D97757" alt="Claude Code · Codex">
  <img src="https://img.shields.io/badge/license-GPL--3.0-4CAF50" alt="license GPL-3.0">
</p>

<p align="center">
  <a href="README.md">English</a> · <b>한국어</b>
</p>

<p align="center">
  <b>AI 에이전트 토큰으로 고양이를 키우고, GitHub 프로필에 자랑하세요.</b><br>
  Claude Code·Codex에 쓴 토큰이 츄르가 되고, 츄르로 입양한 고양이들이 맥북 노치 속 방에서 살아요.
</p>

<p align="center">
  <img src="docs/readme/cards.gif" width="840" alt="배경 다섯 가지로 바뀌는 TokenCats 프로필 카드">
</p>

<p align="center">
  앱이 하루에 한 번, 그리고 방이 바뀔 때마다 토큰을 추적한 GitHub 프로필 카드를 새로 그려요.
</p>

<hr>

> TokenCats는 지금 **Claude Code**와 **Codex**의 토큰을 읽어요.<br>
> 앞으로 Gemini CLI, Kiro 등 더 많은 에이전트를 지원할 예정이에요. 함께 만들어 갈 기여자를 언제나 환영해요!

<p align="center">
  <img src="docs/readme/notch.gif" width="720" alt="노치에 마우스를 올리면 방이 열리고, 쓰다듬으면 하트를 띄우는 고양이들">
</p>

- 노치를 닫아 두면 고양이들이 노치 양옆에 앉아 있어요.
- 노치에 마우스를 올리면 방이 열려요. 방 안의 고양이는 걷고, 그루밍하고, 쓰다듬으면 하트를 띄워요.
- 쓰다듬거나 우클릭으로 츄르를 주면 친밀도 레벨이 99까지 올라요. 고양이에 마우스를 올리면 레벨이 보이고, 설정 › GitHub 프로필에서 "고양이 친밀도 레벨"을 켜면 카드에도 나와요.
- 방 아래에는 보유 츄르, 오늘 쓴 토큰, Claude·Codex 사용 한도가 함께 보여요.

### 어떻게 키우나요

<table>
<tr>
<td width="50%"><img src="docs/readme/store.png" width="100%" alt="입양 상자와 방 배경을 파는 상점"></td>
<td>

1. 🪙 **코딩해요.** Claude Code·Codex에 쓴 토큰을 셉니다.
2. 🐟 **츄르가 쌓여요.** 토큰 1개가 츄르 1개이고, 매일 작은 미션 3개로 보너스를 더 받아요.
3. 📦 **입양해요.** 입양 상자 하나에 1천만 츄르.
4. 🏠 **방을 꾸며요.** 배경과 소품을 사요.
5. 🖼️ **자랑해요.** 방이 GitHub 프로필 카드가 돼요.

</td>
</tr>
</table>

<details>
<summary>츄르는 정확히 어떻게 세나요?</summary>

- 츄르로 세는 토큰은 세 가지입니다: 캐시되지 않은 입력, 캐시 쓰기, 출력.
- 캐시에서 다시 읽은 토큰은 세지 않아요. 같은 내용을 반복해서 읽는 양까지 세면 숫자가 지나치게 부풀기 때문이에요.
- 지난 날의 합계는 그날이 끝나면 고정돼요. 그래서 로그 파일이 지워져도 이미 쌓인 츄르는 줄지 않아요.
</details>

### 내 사용량을 한 눈에

<table>
<tr>
<td width="50%"><img src="docs/readme/stats.png" width="100%" alt="1년 잔디, 최근 7일 요일별 토큰, Claude·Codex 비율을 보여 주는 통계 화면"></td>
<td>

- **1년 잔디:** 하루에 쓴 토큰을 GitHub 잔디처럼 칠해요. 많이 쓴 날에는 발바닥 도장이 찍혀요.
- **365일 합계·하루 평균·연속 사용일**을 한눈에 보여 줘요.
- **최근 7일:** 요일별 토큰과 Claude·Codex 비율, API 요금으로 환산한 추정 비용까지.

</td>
</tr>
</table>

### 내 방으로 꾸미기

<table>
<tr>
<td width="50%"><img src="docs/readme/collection.png" width="100%" alt="배경 다섯 가지와 방에 사는 고양이를 고르는 보관함"></td>
<td>

배경 다섯 가지와 소품, 카드에 넣을 항목(토큰 수, 1년 잔디)을 고를 수 있어요.
- 보관함에서 배경을 누르면 바로 방이 바뀌어요.
- 방에는 네 마리가 살고, 나머지 고양이는 보관함에서 기다려요.

</td>
</tr>
</table>

### GitHub 프로필에 고양이 올리기

<table>
<tr>
<td width="50%"><img src="docs/readme/profile-card.png" alt="포근한 방 배경의 TokenCats 프로필 카드"></td>
<td>

내 고양이 방이 GitHub 프로필 README 맨 위에 카드로 붙어요.

1. 처음 설정에서 **GitHub로 연결**을 누르고
2. **README에 넣기**를 누르면 끝이에요.

- 서버가 없어요. 카드는 내 프로필 저장소의 `catroom` 브랜치에 SVG 하나로 올라가고, README는 표시된 구간만 고쳐요.

</td>
</tr>
</table>

<details>
<summary>프로필 저장소가 처음이라면</summary>

GitHub에서 내 아이디와 같은 이름의 공개 저장소(예: `changchangwoo/changchangwoo`)를 만들면, 그 저장소의 README가 프로필 첫 화면에 보여요. 저장소가 없으면 앱이 만드는 링크를 알려 드려요.
</details>

<details>
<summary>직접 붙이고 싶다면</summary>

앱은 README에 아래 블록을 넣어요. 같은 내용을 직접 붙여도 돼요(`아이디`를 바꿔 주세요).

```md
<!-- tokencats:start -->
<a href="https://github.com/changchangwoo/TokenCats"><img src="https://raw.githubusercontent.com/아이디/아이디/catroom/catroom.svg" width="100%" alt="My cat room and agent activity"></a>
<!-- tokencats:end -->
```
</details>

### 당신을 기다리는 귀여운 고양이들!

입양 상자를 열면 등급에 따라 고양이가 나와요.
어떤 고양이를 만나게 될지 정말 두근두근하지 않나요?

| 등급 | 확률 | 고양이 |
|---|---|---|
| 흔함 | 50% | <img src="docs/readme/cat-black.png" width="64" alt="검정"> <img src="docs/readme/cat-cheese.png" width="64" alt="치즈"> <img src="docs/readme/cat-split.png" width="64" alt="삼색"> <img src="docs/readme/cat-tabby.png" width="64" alt="고등어"> |
| 드묾 | 30% | <img src="docs/readme/cat-white.png" width="64" alt="하양"> <img src="docs/readme/cat-tuxedo.png" width="64" alt="턱시도"> <img src="docs/readme/cat-cream.png" width="64" alt="크림"> |
| 희귀 | 15% | <img src="docs/readme/cat-siamese.png" width="64" alt="샴"> |
| 유니크 | 5% | <img src="docs/readme/cat-foxfire.png" width="64" alt="여우불"> 프로필에 있으면 자랑해도 돼요. |

### 설치

```sh
brew install --cask changchangwoo/tap/tokencats
```

- macOS 14 이상에서 동작해요. 노치가 없는 Mac에서는 메뉴 막대 높이로 보여요.
- 설치 명령은 위처럼 전체 이름으로 입력해 주세요. 짧게 `tokencats`만 쓰면 Homebrew가 설치를 거부해요.
- 업데이트는 `brew upgrade --cask tokencats`예요.
- [Releases](https://github.com/changchangwoo/TokenCats/releases)에서 zip을 직접 받으면 처음 열 때 macOS가 열 수 없다고 해요. 시스템 설정 › 개인정보 보호 및 보안 맨 아래의 **그래도 열기**를 누르거나, 터미널에서 `xattr -dr com.apple.quarantine /Applications/TokenCats.app`을 실행하면 돼요.
- 그 뒤로는 앱이 스스로 업데이트해요. 하루 한 번 새 버전을 확인하고 설치 전에 물어봐요(설정 › 정보).
- 앱은 ad-hoc 서명되어 있고 Apple 공증을 받지 않았어요. 설치할 때 Homebrew cask가 `TokenCats.app`의 macOS 격리 속성을 제거해 앱을 열 수 있게 해요.

<details>
<summary><b>개인정보</b> — 읽는 것, 쓰는 것, 보내는 것</summary>
<br>

| | |
|---|---|
| **읽는 것** | `~/.claude`, `~/.codex`의 사용 기록. 토큰 수와 모델만 셉니다. 프롬프트 내용은 저장하거나 보내지 않아요 |
| **쓰는 것** | 켰을 때만: Claude Code·Codex 설정 파일에 훅 한 줄, Claude Code 상태줄 한 줄. 원래 설정은 백업하고, 끄면 원래대로 돌아가요 |
| **보내는 것** | GitHub App으로 연결하면 기기 인증에 `github.com`을 사용해요. GitHub 카드를 켜면 `api.github.com`을 통해 카드 SVG를 올리고 프로필 README를 읽고 저장해요. README에서는 표시한 구간만 바꿔요. 하루 한 번 `raw.githubusercontent.com`에서 새 버전이 있는지 확인하고, 설치 전에 물어봐요(설정 › 정보에서 끌 수 있어요). 에이전트 사용 기록과 프롬프트는 Mac에 남아요 |
| **사용 통계** | 수집하지 않아요 |
| **계정** | GitHub 연결은 선택이에요. gh 로그인을 쓰거나, TokenCats GitHub App에 프로필 저장소 접근만 허락하면 돼요 |

- 설정 파일을 바꿀 때 기존 설정과 다른 도구의 훅은 건드리지 않아요.
- 훅은 연결한 뒤 새로 열거나 다시 연 세션부터 적용돼요.
- Codex는 연결한 뒤 Codex 안에서 `/hooks`로 한 번 승인해 주세요.
</details>

### 기여하기

- 구조는 [ARCHITECTURE.md](ARCHITECTURE.md)에 있어요.
- 작업 규칙은 [CONTRIBUTING.md](CONTRIBUTING.md)에 있어요.
- 고양이와 방 그림을 더하려면 [art-src/README.md](art-src/README.md)를 보세요.

해당 프로젝트는 언제나 열려 있는 오픈 소스예요.<br>
새로운 고양이, 새로운 방, 새로운 아이템, 그 밖에 새로운 모든 것을 함께할 기여자들을 항상 기다리고 있어요!

### 고마운 분들

- TokenCats는 [boring.notch](https://github.com/TheBoredTeam/boring.notch)(GPL-3.0)에서 시작했어요.<br>
  노치 창과 열고 닫는 움직임을 가져왔고, 자세한 목록은 [NOTICE.md](NOTICE.md)에 있어요.
- 카드 글꼴은 [Baloo 2](https://fonts.google.com/specimen/Baloo+2)예요.

### 라이선스

GPL-3.0

<p align="center">
  <img src="docs/readme/black-groom.gif" width="100%" alt="포근한 방 가운데에서 그루밍하는 검정 고양이">
</p>

<p align="center">
  고양이가 마음에 들었다면 ⭐ 스타를 눌러 주세요. 개발에 큰 도움이 됩니다! 🐟
</p>
