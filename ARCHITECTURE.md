# TokenCats 구조

## 세 층

```
app/TokenCats/
  Core/        규칙과 데이터. SwiftPM 타겟 TokenCatsCore. UI 없음, 테스트 대상.
  Features/    화면. 한 폴더가 한 화면(Home · Cats · Store · ClosedNotch · Profile · Settings · Shared).
  NotchShell/  boring.notch에서 가져온 노치 창: 열고 닫기, 제스처, 크기, 애니메이션, 환영 화면.
  App/         진입점(TokenCatsApp)과 메뉴 막대.
  Resources/   JSON 카탈로그, 고양이·방 그림(빌드 결과물), 폰트, 훅 스크립트.
Tests/TokenCatsCoreTests/   Core와 같은 폴더 구조.
art-src/      그림 원본. 고양이·방 그림은 여기만 고칩니다(art-src/README.md).
```

의존 방향: **Features → Core**이고, **NotchShell**은 창을 띄우며 Features의 화면을 담습니다. Features는 NotchShell의
창 상태 두 가지(`NotchCoordinator`: 열린 탭·디스플레이, `BatteryStatusViewModel`: 배터리)만 읽습니다. Core는
`Foundation`·`Combine`·`Darwin`·`os.log`만 import하고 SwiftUI·AppKit·`Defaults`를 모릅니다. 그래서 `swift test`가
Xcode 없이 돌고, 카드·장부·방 배치 같은 규칙은 전부 테스트로 고정되어 있습니다.

`NotchShell`은 빌린 코드라는 뜻입니다. 파일마다 출처 주석이 있고, 동작하는 범위에서 최소로만 고칩니다.
노치와 무관한 TokenCats의 규칙이 그 안에 들어가면 안 됩니다. 예외는 `FullscreenDetector`로, boring.notch가 외부
패키지로 하던 전체 화면 감지를 직접 쓴 것입니다(전체 화면 앱 위에서는 닫힌 노치와 고양이가 숨습니다).

## 데이터 흐름

```
에이전트 로그 (~/.claude, ~/.codex)
   └─ TokenUsageReader · DailyTokenScan  ─┐
훅 스크립트 → SocketServer → AgentHub      │   (세션 알림만; 츄르와 무관)
                                           ▼
                         ChuruLedger → ChuruModel (잔액 · 오늘 · 연속일)
                                           │
                     StoreService ─ 구매 ─▶ CatHousehold · StoreInventory (cats.json · inventory.json)
                                           │
                   CatRoomScene · CatRoomMotion ─▶ CatRoomView (노치 안 방) / ClosedNotchView (닫힌 노치)
                                           │
                      CatRoomSVG · ContributionYear ─▶ ProfileCard ─▶ ProfileSync ─▶ GitHub README
```

- 모든 데이터 파일 이름은 `Core/Support/DataFiles.swift` 한 곳에 있습니다. `Backup`은 그 목록으로 백업·복원·초기화합니다.
- 사용자 설정의 키와 기본값은 `Features/Settings/AppSettings.swift`(키)와 `Core/Settings/Preferences.swift`(기본값)에만 있습니다.
  뷰는 `@AppStorage(AppSettings.Key.x) private var x = AppSettings.Default.x` 패턴으로만 읽습니다.
- 경로는 `AppPaths`. Debug 빌드에서는 `NC_SUPPORT_DIR` 환경 변수로 데이터 폴더를 바꿀 수 있어 스냅숏과 테스트가 고정 사본을
  씁니다(Release는 무시합니다: 훅 스크립트의 소켓 경로가 고정이라 둘이 갈라지면 안 됩니다).

## 앱 수명 상태

`StoreModel`, `ChuruModel`, `CostUsageModel`, `UsageLimitsModel`, `HomeUsageHistoryModel`, `UIDisplayModel`, `ProfileSync`,
`CatSprites`, `CatRoomStage`는 `.shared` 싱글턴입니다. 노치 창이 여러 디스플레이에 떠도 데이터는 하나여야 해서 그렇습니다.

규칙:
- 뷰는 `@ObservedObject`로만 접근하고, 싱글턴끼리는 서로의 UserDefaults를 직접 읽지 않고 `AppSettings`를 통합니다.
- 상태 변경은 `StoreService`·`ChuruTracker` 같은 Core 타입이 하고, 싱글턴은 그 결과를 메인 스레드에 올려 줄 뿐입니다.
- Core의 싱글턴은 `SocketServer`·`AgentHub` 둘뿐이고, 둘 다 프로세스 수명의 서비스입니다.

## 확장 지점

### 고양이를 더하려면
`art-src/cats/<새 코트>/`에 동작별 그림 4개(걷기 둘, 쉬기, 그루밍. 쓰다듬기는 그루밍에서, 작은 고양이는 쉬기에서 가져옴)를 두고
`swift scripts/build-cat-art.swift`를 돌리면 코트가 생깁니다. 무엇을 어느 파일에 그리는지는 [art-src/README.md](art-src/README.md)에
있습니다. `Resources/store-catalog.json`의 입양 상자 등급에 코트를 넣으면 상점에 나옵니다. `CatAssetCatalogTests`가 모든 코트의
크기·바닥선·이음새와, 앱 리소스가 원본 폴더와 똑같은지를 검사합니다.

### 방 테마를 더하려면
`art-src/rooms/<테마>/`에 벽·바닥 원본을 두고 `scripts/import-room-art.swift`로 `Resources/RoomArt/`에 PNG(1x·2x)를 만듭니다.
`Resources/room-themes.json`에 테마(색·식별자)를, `store-catalog.json`에 가격을 넣습니다. `RoomThemeTests`가 카탈로그와 그림
파일이 서로 맞는지, 카드 미리보기 대비가 충분한지 검사합니다.

### 에이전트를 더하려면
`Core/Agents/AgentIntegration.swift`에 케이스를 추가하고 설정 파일 경로와 훅 이벤트를 답하게 합니다.
`Resources/tokencats-hook.py`는 첫 인자로 받은 provider 이름을 소켓 메시지에 실어 보내므로, 이벤트 이름이 다르면
그 스크립트의 분기와 `AgentSession`의 상태 매핑을 함께 고칩니다. 토큰 집계는 `TokenUsageReader`에 로그 형식을 추가합니다.

### 언어를 더하려면
`Resources/Localizable.xcstrings`에 그 언어의 열을 더하면 끝입니다. 설정의 언어 목록은 번들에 든 언어(`Bundle.main.localizations`)
에서 `AppLanguage`가 만들고, 이름은 그 언어의 자기 이름으로 나옵니다. 코드는 고치지 않습니다. 한국어처럼 번역 조각
(`Resources/l10n/*.json`)으로 관리하려면 `scripts/build-string-catalog.py`의 `TARGETS`에 언어 코드를 넣습니다.
언어는 루트 뷰 네 곳(노치·설정·온보딩·메뉴바)에 `.localized()`가 거는 `environment(\.locale)` 하나로 흐르므로, 설정에서
고르는 순간 재실행 없이 바뀝니다. 프로필 카드 SVG는 전 세계에 보이는 것이라 언제나 영어입니다.

## 테스트와 검증

- Core는 Swift Testing(`swift test`). 새 규칙은 실패하는 테스트부터 씁니다.
- UI는 Debug 빌드 + 스냅숏입니다. `scripts/snapshot.sh <dir>`가 카드 5종 SVG와 화면 PNG를 뽑고,
  `scripts/compare-snapshots.py <base> <new>`가 바이트/픽셀로 비교합니다. 카드는 바이트까지 같아야 합니다.
  `TOKENCATS_LAUNCH_ARGS="-companionLanguage en"`처럼 앱 인자를 더해 언어별로 뽑을 수 있습니다.
- 문구는 `python3 scripts/check-strings.py`. 소스의 한글 리터럴과 카탈로그의 번역 누락을 잡습니다.

## 이름과 예전 이름

디스크에 닿는 식별자는 모두 TokenCats 이름입니다. "Notch Companion" 시절에 설치한 사용자는
첫 실행 때 `LegacyDataMigration`(App)과 `IdentityMigration`(Core)이 한 번 옮깁니다. 예전 이름은
`Core/Support/LegacyIdentity.swift`에만 있고, 훅·상태줄·README 블록은 예전 마커도 우리 것으로 알아봅니다.

| 식별자 | 지금 값 | 예전 값 (옮겨짐) |
|---|---|---|
| `.app` 이름 (`PRODUCT_NAME`) | `TokenCats` | `Notch Companion` |
| 번들 ID | `io.github.changchangwoo.tokencats` | `com.changwoo.notchcompanion` (설정을 복사, `SU*` 제외) |
| 데이터 폴더 | `~/Library/Application Support/TokenCats/` | `.../NotchCompanion/` (통째로 이동) |
| 소켓 | `<데이터 폴더>/companion.sock`, 경로가 길면 `~/.tokencats/` | |
| 훅·상태줄 스크립트 | `tokencats-hook.py`, `tokencats-statusline.py` | `notch-companion-*.py` (명령을 새 경로로 다시 씀) |
| 설정 파일 백업 | `*.tokencats.bak`, `*.tokencats-statusline.bak` | 상태줄 첫 백업은 이름을 바꿈 |
| README 마커 | `<!-- tokencats:start -->` … `<!-- tokencats:end -->` | 그대로 알아보고, README에 다시 넣을 때 새 마커로 바뀜 |
| 키체인 | 서비스 `TokenCats.github` | 옮기지 않음 (device flow를 켠 적이 없어 저장된 토큰이 없음) |
| UserDefaults 키 | `companion*`, `profile*`, `roomThemeID` 등 (`AppSettings.Key`) | 키 이름은 그대로 |
