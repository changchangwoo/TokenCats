# Cat art pipeline

**How to edit the art is in [`art-src/README.md`](../../art-src/README.md); the frame specification and the procedures
are defined in [`sprite.rules` in `AGENTS.md`](../../AGENTS.md#spriterules).** This document describes what happens
behind them.

## Flow

```
build/incoming-<coat>/*.png                                   (incoming large artwork sheets, not committed)
        │  swift scripts/import-cat-art.swift <coat> …   — find frames, one scale per sheet, floor line y=93, alpha 0/255, idle = groom[0]
        ▼
art-src/cats/<coat>/walk-right.png, walk-left.png, idle.png, groom.png      (sources, 96px frames; hand edits happen here)
        │  swift scripts/build-cat-art.swift   — stitch and check sizes only; no scaling or correction
        ▼
app/TokenCats/Resources/CatArt/cat-<coat>.png          (23-frame sheet)
                               cat-assets.json            (action → frame indices in the sheet)
        │  read by the app at run time
        ▼
CatSprites (Features/Cats) — crops the sheet by action name and frame order
```

## Sheet layout

Each coat is one sheet of **23** 96×96px frames side by side. The order is set by the `clips` table in
`build-cat-art.swift`.

| Frames | Action (`clip` in `cat-assets.json`) | Source file |
|---|---|---|
| 0–5 | `walkRight` | `walk-right.png` |
| 6–11 | `walkLeft` | `walk-left.png` |
| 12 | `idle` | `idle.png` |
| 13–22 | `groom` | `groom.png` |
| 17, 21 | `pet` | Shares the 5th and 9th groom frames (`petFromGroom`) |

App code never knows frame numbers. `CatRoomMotion` decides only "action + which frame", and `CatSprites` finds the
sheet frame through `cat-assets.json`. To change the layout, edit the `clips` table and nothing else.

## Importer (`scripts/import-cat-art.swift`)

- Finds opaque blobs (alpha ≥ 160) in the sheet and reads them in row and column order. Touching frames cannot be
  separated. `file#row` selects a single row.
- The groom sheet gets one scale that makes frame 0 (the sitting pose) `--idle-height` tall (default 88); that
  produces the 10 groom frames, and frame 0 becomes `idle.png`.
- Each walk sheet gets one scale at which its largest frame is at most `--walk-height` (default 84) and no frame is
  wider than 88. A picture with the tail held high comes out with a smaller body, so judge the result by head and body
  size.
- Downscaling is nearest-pixel (keeps the pixel look), alpha is split into 0/255 at a threshold of 160, and colours are
  un-premultiplied.
- Each frame is set on the floor line y=93 and centred, then shifted by up to ±8px to the position where its
  silhouette overlaps frame 0 of the same action the most (so the body stays put and only paws and tail move).
- No small picture (store, collection, closed notch) is produced. The app crops 80×80 from (8, 0) of the idle frame
  (`CatSprites.portrait`).

## Checks (`swift test`, `CatAssetCatalogTests`)

- `shippedArtIsExactlyTheSourceFolder`: the app's sheets and icons equal `art-src/cats/<coat>/` stitched together
  as is. Fails if the output was hand-edited, or the sources changed without a build.
- `everyCoatHasACompleteAtlas`: the sheet holds exactly the frames the actions use (no spare frames, no missing
  indices).
- `groomingStartsFromTheIdlePose`: the first groom frame is pixel-identical to the resting pose.
- `idleGroomAndPetHaveMatchingSizeAndFloor`: groom and pet frames share the resting pose's floor line, differ in
  height by at most 6px, and overlap it enough.
- How many forepaws are visible in groom and pet frames cannot be judged automatically; check with `--gif-preview` by
  eye.

## Run-time rules

- `idle`, `walkRight`, `walkLeft`, `groom` and `pet` are referenced by name. Their sheet positions exist only in the
  JSON.
- Sheets are read per coat on demand and their frames are cached.
- Up to 10 cats are owned, and `CatHousehold.roomCapacity` (4) live in the room. A cat picks its art by coat, and
  several cats of the same coat are allowed.

## History

Originally the build script cropped and downscaled the large artwork sheets (`docs/design/cat-*-source.png`) and
overrode some frames with corrected versions. It was hard to tell which frame came from which file, so the structure
was changed to the current one. The downscaling logic moved into `scripts/import-cat-art.swift`, which now runs once
when a new coat is brought in rather than on every build (the calico `split` was the first case).
