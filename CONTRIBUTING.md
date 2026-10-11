# 기여 안내

## 시작하기

```bash
git clone <repo> && cd <repo>
swift test                        # Core 테스트. Xcode 없이 Command Line Tools로도 돕니다 (scripts/test.sh 참고)
open app/TokenCats.xcodeproj      # 앱은 Xcode로. 스킴 TokenCats
scripts/build-app.sh && scripts/run-app.sh
```

## 작업 규칙

- **Core는 테스트 먼저.** 규칙(장부, 상점, 방 배치, 카드, 설정 기본값)을 바꿀 때는 실패하는 테스트를 쓰고 통과시킵니다.
  Core는 SwiftUI·AppKit·Defaults를 import하지 않습니다.
- **UI는 스냅숏으로 확인.** 화면을 건드리면 `scripts/snapshot.sh`로 전후를 뽑아 `scripts/compare-snapshots.py`로 비교합니다.
  의도한 변화만 달라야 합니다. 카드 SVG는 렌더러를 바꾸지 않는 한 바이트까지 같습니다.
- **파일 하나에 타입 하나.** 파일 이름은 그 안의 주된 타입 이름입니다. 화면은 `Features/<화면>/`에, 규칙은 `Core/<영역>/`에 둡니다.
- **설정은 한 곳.** 새 설정은 `AppSettings.Key`와 `PreferenceDefaults`에 추가하고, 뷰에 리터럴 기본값을 쓰지 않습니다.
- **NotchShell은 최소 수정.** boring.notch에서 온 코드는 동작에 필요한 만큼만 고칩니다. TokenCats의 규칙을 거기 넣지 않습니다.
- **코드의 문구는 영어 키, 한국어는 카탈로그.** 뷰에는 `Text("Store")`처럼 영어 리터럴을 쓰고, 한국어는
  `Resources/l10n/<영역>.json`에 `"Store": "상점"`으로 적은 뒤 `python3 scripts/build-string-catalog.py`로
  `Localizable.xcstrings`를 만듭니다(카탈로그는 손으로 고치지 않습니다). 변수가 들어가는 문장과 상태·반환값은
  `String`이 아니라 `LocalizedStringResource`로 두어 언어를 바꾸면 함께 바뀌게 합니다. Core는 사람이 읽는 문장을
  만들지 않고 enum·값만 돌려줍니다. `python3 scripts/check-strings.py`가 소스의 한글 리터럴과 번역 누락을 잡습니다.

## 커밋

`type: 요약` 형식([Conventional Commits](https://www.conventionalcommits.org/))입니다. `type`은 feat · fix · refactor · docs · chore · test · art, 요약은 한국어나 영어 모두 됩니다. 한 커밋은 한 가지 변화만 담고,
본문에는 왜 그렇게 했는지와 확인한 방법(테스트 수, 스냅숏 결과)을 적습니다.

## PR 전에

1. `swift test` 전부 통과
2. Debug 빌드 성공 (`scripts/snapshot.sh /tmp/snap`이 빌드까지 합니다)
3. `python3 scripts/check-strings.py`가 `strings ok`
4. 화면을 바꿨다면 스냅숏 비교 결과를 PR에 적기. 문구를 바꿨다면 `TOKENCATS_LAUNCH_ARGS="-companionLanguage ko"`로
   뽑은 한국어 스냅숏이 전과 같은지도 봅니다
5. 새 고양이·테마·에이전트·언어는 [ARCHITECTURE.md](ARCHITECTURE.md)의 확장 지점 절을 따르기
