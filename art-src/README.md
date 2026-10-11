# 그림 원본

앱에 들어가는 그림의 **원본은 이 폴더에만** 있습니다. `app/TokenCats/Resources/CatArt/`와 `RoomArt/`는 스크립트가 만드는
결과물이니 직접 고치지 마세요. 직접 고치면 다음 빌드에 덮어써지고, 고양이는 테스트(`shippedArtIsExactlyTheSourceFolder`)가
실패합니다.

## 고양이: `cats/<코트>/`

코트 하나가 폴더 하나입니다(`black`, `cheese`, `cream`, `foxfire`, `siamese`, `split`, `tabby`, `tuxedo`, `white`). 파일 안의 그림이 **픽셀 그대로** 앱에 들어갑니다.
축소·보정·덮어쓰기가 없으니, 보이는 그대로가 앱에서 보이는 그림입니다.

| 바꾸려는 것 | 고칠 파일 | 크기 |
|---|---|---|
| 오른쪽으로 걷기 | `walk-right.png` | 576×96 (96px 6칸, 왼쪽부터 재생) |
| 왼쪽으로 걷기 | `walk-left.png` | 576×96 (6칸) |
| 쉬는 자세 (상점·보관함 얼굴, 카드도 이 그림) | `idle.png` | 96×96 (1칸) |
| 그루밍 | `groom.png` | 960×96 (10칸) |
| 쓰다듬을 때 | 따로 없음: `groom.png`의 **5번째·9번째 칸**이 그대로 쓰입니다 | — |
| 닫힌 노치에 앉은 작은 고양이 | `icon.png` | 24×24 |
| 닫힌 노치에서 눈 깜빡일 때 | `icon-blink.png` | 24×24 |

칸이 지켜야 할 규칙(바닥선 y=93, 알파 0/255, 그루밍 첫 칸 = `idle.png`, 폭 88px 이하 등)과 테스트가 검사하는 항목은
**[`AGENTS.md`의 `sprite.rules`](../AGENTS.md#spriterules)** 에 있습니다. 여기서는 되풀이하지 않습니다.

### 고친 다음

```bash
swift scripts/build-cat-art.swift            # 시트·아이콘·cat-assets.json 만들기
swift scripts/build-cat-art.swift --gif-preview   # + build/cat-art-preview/에 동작별 GIF (커밋 안 됨)
swift test                                   # 크기·바닥선·이음새·원본 일치 검사
```

`icon.png`를 바꿨다면 눈 감은 아이콘을 손으로 그리거나, `swift scripts/make-blink-icons.swift`로 자동으로 만든 뒤 빌드합니다.

### 새 고양이를 더하려면

큰 원화 시트(AI 생성 등)가 있으면 `swift scripts/import-cat-art.swift <코트> --walk-right … --walk-left … --groom …`이
위 6개 파일을 규칙에 맞게 만들어 줍니다. 그 뒤 깜빡임 아이콘 → 빌드 → 테스트 → `CatNames.swift`의 이름과
`store-catalog.json`의 입양 상자 등급 순서입니다. 단계별 체크리스트는 `AGENTS.md`의 **새 고양이 추가 절차**를 따릅니다.
96px 칸을 바로 그릴 수 있으면 기존 코트 폴더를 복사해 그 위에 그려도 됩니다.

## 방 배경: `rooms/<테마>/`

`wall`·`floor` 원본 그림입니다. 이건 크기가 자유로운 원본이라 스크립트가 카드 폭(840pt)에 맞춰 줄이고 잘라 냅니다.

```bash
swift scripts/import-room-art.swift wall  art-src/rooms/<테마>/wall.png  <테마> [top]
swift scripts/import-room-art.swift floor art-src/rooms/<테마>/floor.png <테마> [top]
```

결과는 `app/TokenCats/Resources/RoomArt/room-<테마>-wall.png`·`-floor.png`(1x·@2x)입니다. 새 테마는
`Resources/room-themes.json`(색)과 `store-catalog.json`(가격)에도 넣습니다.
