# TokenCats — 에이전트 규칙

이 파일은 저장소 안에서 작업하는 에이전트(와 사람)가 지켜야 할 규칙의 정본입니다. 사람용 안내는 각 영역의 README가
맡고, 규칙이 충돌하면 이 파일이 이깁니다.

## sprite.rules

고양이 그림(스프라이트)에 관한 규칙입니다. 사람용 설명은 [`art-src/README.md`](art-src/README.md), 빌드 뒤에서
일어나는 일은 [`docs/design/cat-art-pipeline.md`](docs/design/cat-art-pipeline.md)에 있고, 둘 다 규칙은 여기를 가리킵니다.

### 원본과 생성물

- **원본은 `art-src/cats/<코트>/` 뿐**입니다. 코트 하나가 폴더 하나이고, 폴더가 곧 코트 목록입니다. 폴더에는 정확히 4개
  파일이 있습니다: `walk-right.png`(576×96, 6칸), `walk-left.png`(576×96, 6칸), `idle.png`(96×96), `groom.png`(960×96, 10칸).
  쓰다듬기 파일은 없습니다(아래). 상점·보관함·닫힌 노치의 작은 고양이는 따로 그리지 않고 `idle.png`의 위쪽 80×80을 잘라 씁니다.
- `app/TokenCats/Resources/CatArt/*`(`cat-<코트>.png`, `cat-assets.json`)는
  `scripts/build-cat-art.swift`가 원본을 **픽셀 그대로** 이어 붙여 만드는 생성물입니다. **절대 손으로 고치지 않습니다.**
  고치면 다음 빌드에 덮어써지고 `shippedArtIsExactlyTheSourceFolder` 테스트가 실패합니다.
- `build/`(미리보기 GIF, 들어온 원화 등)는 커밋하지 않습니다.

### 칸(프레임) 규격

| 항목 | 규칙 | 검사 |
|---|---|---|
| 크기 | 칸은 96×96, 배경 투명 | 빌드 스크립트 |
| 알파 | 0 또는 255만. 반투명 픽셀 없음 | 임포터가 보장, 눈으로 확인 |
| 바닥선 | 실루엣의 맨 아래 불투명 줄이 **y=93**(아래 여백 2px). 모든 칸이 같음 | `idleGroomAndPetHaveMatchingSizeAndFloor` |
| 크기 범위 | 앉은 자세(idle) 실루엣 약 70–83 × 86–89px. 걷기 칸은 머리·몸통 크기가 검은 고양이(`black`)와 비슷하게. 어떤 칸도 **폭 88px 이하**(방의 충돌 범위) | `everyCoatFitsTheRoomsCollisionEnvelope` |
| 걷기 방향 | `walk-right`는 코가 오른쪽, `walk-left`는 코가 왼쪽. 비대칭 무늬(삼색 `split`)는 좌우 반전으로 만들지 않음 | `cheeseWalkFramesFaceTheirTravelDirection`(치즈만), 나머지는 눈으로 |
| 그루밍 시작 | `groom.png`의 **0번 칸은 `idle.png`와 픽셀까지 같음**. 9번 칸은 idle과 거의 같은 자세로 돌아옴 | `groomingStartsFromTheIdlePose` |
| 그루밍 크기 | 그루밍 칸은 idle과 바닥선이 같고 높이 차 6px 이내, 실루엣 겹침(IoU) idle↔groom[0] ≥ 0.8 | 같은 테스트 |
| 쓰다듬기 | 파일 없음. **`groom.png`의 4번·8번 칸**(0부터 셈)을 그대로 씀. 두 칸은 **앞발 하나를 들고 눈을 감은 자세**이고 idle과 IoU ≥ 0.75. 앞발은 든 것 하나 + 디딘 것 하나(디딘 앞발이 둘이면 결함) | `petFromGroom`, `idleGroomAndPetHaveMatchingSizeAndFloor` |
| 작은 그림 | 따로 없음. 상점·보관함·닫힌 노치는 `idle.png`의 (8, 0)부터 80×80을 씀. 얼굴과 앞모습이 그 안에 들어오게 그림 | 눈으로 |
| 기준 코트 | 동작의 타이밍·크기 기준은 `black`입니다. 새 코트는 검은 고양이 옆에 놓고 비교합니다 | 눈으로 |

### 명령

```bash
swift scripts/import-cat-art.swift <코트> --walk-right <시트> --walk-left <시트>|mirror --groom <시트>   # 큰 원화 → art-src/cats/<코트>/ 4개 파일
swift scripts/build-cat-art.swift --gif-preview       # Resources/CatArt 생성 + build/cat-art-preview/<코트>-<동작>.gif
swift test                                            # CatAssetCatalogTests 등 전체
```

### 새 고양이 추가 절차

들어온 원화(보통 AI 생성 시트)를 코트로 만드는 순서입니다. 각 단계에서 어긋나면 멈추고 PR(또는 이슈)에 적습니다.

1. **검토(assess)**: 원화를 `build/incoming-<코트>/`에 두고 아래를 확인해 결과를 적습니다.
   - 시트 구성: 오른쪽 걷기 6칸, 왼쪽 걷기 6칸, 그루밍 10칸(0번 = 앉은 자세, 4·8번 = 앞발 들고 눈 감음). 칸끼리 닿지 않는
     투명 배경이어야 임포터가 칸을 찾습니다. 체커보드나 단색이 구워진 배경은 쓰지 않습니다(외곽선과 구분되지 않음).
   - 몸에서 떨어진 조각(여우불의 불꽃 같은 것)은 가장 큰 덩어리의 1/4보다 작으면 임포터가 가장 가까운 칸에 붙입니다.
     그보다 크면 칸으로 잘못 잡히니, 칸 수가 6·6·10으로 나오는지 확인합니다.
   - 포즈가 빠졌으면(예: 왼쪽 걷기 없음, 그루밍 10칸 미만) **그리지 말고 멈춰서** PR에 적습니다. 대칭 무늬 코트만 `--walk-left mirror`로 대신할 수 있습니다.
   - 결함(디딘 앞발이 둘, 잘린 꼬리, 떠 있는 조각)은 적어 두고, 96px에서 몇 픽셀로 고칠 수 있는 것만 고칩니다.
2. **임포트**: `swift scripts/import-cat-art.swift <코트> --walk-right … --walk-left … --groom …`. 출력된 크기(폭×높이@왼쪽)와
   스케일을 확인합니다. 시트마다 스케일 하나, 바닥선 y=93, 알파 0/255, idle = groom[0]이 자동으로 맞습니다.
3. **눈으로 비교**: 각 strip을 `black`의 같은 strip과 나란히 3배로 보고 머리·몸통 크기, 걷는 방향, 쓰다듬기 칸(4·8번)의 앞발 수를
   확인합니다. 작은 결함은 strip에서 픽셀로 고치고(Pixelorama 또는 스크립트) 어떤 칸을 어떻게 고쳤는지 PR 설명에 적습니다.
   **임포터를 다시 돌리면 손 수정이 사라집니다**(`--force` 필요). 원화가 바뀌었을 때만 다시 임포트합니다.
4. **빌드**: `swift scripts/build-cat-art.swift --gif-preview` → `build/cat-art-preview/<코트>-*.gif`를 봅니다.
5. **테스트**: `swift test` 전부 통과. `CatAssetCatalogTests`는 카탈로그의 모든 코트에 대해 돕니다.
6. **이름·등급**: `app/TokenCats/Core/Cats/CatNames.swift`에 한국어 이름, `app/TokenCats/Resources/store-catalog.json`의 입양 상자
   등급에 코트 id. 코트를 나열하는 테스트도 함께 고칩니다: `StoreCatalogTests`(`bundledCatalogMatchesThePriceList`의 등급별 배열. 등급을 비우는 테스트들은 카탈로그에서 등급을 읽으므로 손댈 필요 없음), `StoreServiceTests`(coats 집합),
   `CatRoomTests`(코트 목록 2곳), `CatNamesTests`. `art-src/README.md`의 코트 목록도 갱신합니다.
7. **앱 빌드·스냅샷·커밋**: Debug 빌드가 되는지, `scripts/snapshot.sh` + `scripts/compare-snapshots.py`에서 새 코트가 보이는
   화면(상점 입양) 말고는 달라진 것이 없는지 확인하고 `feat: …`로 커밋합니다. 들어온 원화는 커밋하지 않습니다.

### 기존 고양이 수정 절차

1. `art-src/cats/<코트>/`의 strip을 Pixelorama(또는 픽셀 단위 스크립트)로 고칩니다. 칸 배치·크기·바닥선은 그대로 둡니다.
   `groom.png` 0번 칸을 고쳤으면 `idle.png`도 같은 그림으로 맞춥니다(반대도 같음). 4·8번 칸을 고치면 쓰다듬기도 바뀝니다.
2. `swift scripts/build-cat-art.swift --gif-preview` → GIF 확인 → `swift test` → 커밋(`art: …` 또는 `fix: …`).

### 규격에 맞지 않을 때

- 몇 픽셀로 고칠 수 있는 결함(중복 앞발, 떠 있는 점, 바닥선 1–2px 차이)은 strip에서 고치고 PR 설명에 적습니다.
- 포즈가 빠졌거나 방향이 틀렸거나 다른 그림체이거나 반투명/체커보드 배경을 걷어낼 수 없으면 **출시하지 않고** 무엇이 왜 안 되는지
  적어 원화를 다시 요청합니다. "그럭저럭 맞춰서" 넣는 것보다 빠진 채로 두는 쪽이 낫습니다.
