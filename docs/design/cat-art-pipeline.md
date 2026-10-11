# 고양이 그림 파이프라인

**그림을 고치는 방법은 [`art-src/README.md`](../../art-src/README.md)에, 칸의 규격·절차의 정본은
[`AGENTS.md`의 `sprite.rules`](../../AGENTS.md#spriterules)에 있습니다.** 이 문서는 그 뒤에서 무슨 일이 일어나는지를 적습니다.

## 흐름

```
build/incoming-<코트>/*.png                                   (들어온 큰 원화 시트, 커밋 안 됨)
        │  swift scripts/import-cat-art.swift <코트> …   — 칸 찾기, 시트당 스케일 하나, 바닥선 y=93, 알파 0/255, idle = groom[0]
        ▼
art-src/cats/<코트>/walk-right.png, walk-left.png, idle.png, groom.png, icon.png, icon-blink.png      (원본, 96px 칸. 손 수정은 여기서)
        │  swift scripts/build-cat-art.swift   — 이어 붙이고 크기만 검사. 축소·보정 없음
        ▼
app/TokenCats/Resources/CatArt/cat-<코트>.png          (23칸 시트)
                               cat-<코트>-icon(-blink).png (복사)
                               cat-assets.json            (동작 → 시트 칸 번호)
        │  앱이 실행 중에 읽음
        ▼
CatSprites (Features/Cats) — 동작 이름과 칸 순서로 시트에서 잘라 그림
```

## 시트 배치

코트마다 96×96px 프레임 **23칸**을 가로로 붙인 시트 한 장입니다. 순서는 `build-cat-art.swift`의 `clips` 표가 정합니다.

| 칸 | 동작(`cat-assets.json`의 clip) | 원본 파일 |
|---|---|---|
| 0–5 | `walkRight` | `walk-right.png` |
| 6–11 | `walkLeft` | `walk-left.png` |
| 12 | `idle` | `idle.png` |
| 13–22 | `groom` | `groom.png` |
| 17, 21 | `pet` | 그루밍의 5·9번째 칸을 같이 씀(`petFromGroom`) |

앱 코드는 칸 번호를 모릅니다. `CatRoomMotion`은 "동작 + 몇 번째 칸"만 정하고, `CatSprites`가 `cat-assets.json`으로 시트 칸을 찾습니다.
배치를 바꿀 때는 `clips` 표만 고치면 됩니다.

## 임포터 (`scripts/import-cat-art.swift`)

- 시트에서 불투명(알파 ≥ 160) 덩어리를 찾아 줄·칸 순서로 읽습니다. 칸끼리 닿으면 못 찾습니다. `파일#줄`로 한 줄만 고를 수 있습니다.
- 그루밍 시트의 0번 칸(앉은 자세) 높이가 `--idle-height`(기본 88)가 되는 스케일 하나로 그루밍 10칸을 만들고, 0번 칸이 `idle.png`가 됩니다.
- 걷기 시트는 각각 가장 큰 칸이 `--walk-height`(기본 84) 이하, 어떤 칸도 폭 88 이하가 되는 스케일 하나를 씁니다. 꼬리를 높이 든 그림은
  그만큼 몸이 작아지니 결과는 머리·몸통 크기로 판단합니다.
- 가장 가까운 픽셀 하나를 고르는 방식으로 줄이고(도트 유지), 알파는 160 기준으로 0/255로 나누고, 색은 프리멀티플라이를 풀어 씁니다.
- 칸마다 바닥선 y=93에 맞추고 가운데 둔 뒤, 같은 동작의 0번 칸과 실루엣이 가장 많이 겹치는 위치로 ±8px 옮깁니다(몸은 그대로, 발·꼬리만 움직이게).
- `icon.png`는 idle의 얼굴 부분(`idle[8 + x*80/24, y*80/24]`), `icon-blink.png`는 일단 복사본이라 `make-blink-icons.swift`를 돌려야 합니다.

## 검사 (`swift test`, `CatAssetCatalogTests`)

- `shippedArtIsExactlyTheSourceFolder`: 앱의 시트·아이콘이 `art-src/cats/<코트>/`를 그대로 이어 붙인 것과 같은지. 결과물을 손으로 고쳤거나 원본을 고치고 빌드를 안 돌렸으면 실패합니다.
- `everyCoatHasACompleteAtlas`: 시트가 동작이 쓰는 칸만 정확히 담는지(남는 칸·빈 번호 없음).
- `groomingStartsFromTheIdlePose`: 그루밍 첫 칸이 쉬는 자세와 픽셀까지 같은지.
- `idleGroomAndPetHaveMatchingSizeAndFloor`: 그루밍·쓰다듬기 칸이 쉬는 자세와 바닥선이 같고 높이 차 6px 이내인지, 실루엣이 충분히 겹치는지.
- 그루밍·쓰다듬기에서 앞발이 몇 개 보이는지는 자동으로 판별하지 못하므로 `--gif-preview`로 눈으로 확인합니다.

## 실행 중 규칙

- `idle`, `walkRight`, `walkLeft`, `groom`, `pet`은 이름으로 참조합니다. 시트 내 위치는 JSON에만 있습니다.
- 시트는 코트별로 필요할 때 읽고 프레임을 캐시합니다.
- 최대 10마리를 보유하고 방에는 `CatHousehold.roomCapacity`(4)마리가 삽니다. 고양이는 털색(`coat`)으로 그림을 고르고, 같은 털색 여러 마리도 가능합니다.

## 지난 이력

예전에는 큰 원화 시트(`docs/design/cat-*-source.png`)를 빌드 스크립트가 잘라 축소하고, 일부 칸을 교정본으로 덮어썼습니다.
어느 칸이 어느 파일에서 오는지 알기 어려워 지금 구조로 바꿨습니다.
그 축소 로직은 `scripts/import-cat-art.swift`로 옮겨, 빌드가 아니라 새 코트를 들일 때 한 번만 돌립니다(삼색 `split`이 첫 사례).
