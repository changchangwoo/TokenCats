# Art sources

The **sources** for the art that goes into the app live **only in this folder**. `app/TokenCats/Resources/CatArt/` and
`RoomArt/` are produced by scripts, so do not edit them directly: a direct edit is overwritten by the next build, and
for cats the `shippedArtIsExactlyTheSourceFolder` test fails.

## Cats: `cats/<coat>/`

One coat is one folder (`black`, `cheese`, `cream`, `foxfire`, `siamese`, `split`, `tabby`, `tuxedo`, `white`). The
pictures in these files go into the app **pixel for pixel**. There is no scaling, correction or overriding, so what you
see here is exactly what the app shows.

| To change | Edit this file | Size |
|---|---|---|
| Walking right | `walk-right.png` | 576×96 (6 frames of 96px, played from the left) |
| Walking left | `walk-left.png` | 576×96 (6 frames) |
| Resting pose (the face in the store and collection; the card uses this too) | `idle.png` | 96×96 (1 frame) |
| Grooming | `groom.png` | 960×96 (10 frames) |
| Being petted | No separate file: the **5th and 9th frames** of `groom.png` are used as they are | — |

The rules a frame must follow (floor line y=93, alpha 0/255, first groom frame = `idle.png`, width ≤ 88px and so on)
and what the tests check are in **[`sprite.rules` in `AGENTS.md`](../AGENTS.md#spriterules)**. They are not repeated
here.

### After editing

```bash
swift scripts/build-cat-art.swift            # build the sheets, icons and cat-assets.json
swift scripts/build-cat-art.swift --gif-preview   # + one GIF per action in build/cat-art-preview/ (not committed)
swift test                                   # size, floor line, seams, source-match checks
```

The small cat in the store, the collection and the closed notch is not drawn separately. It is the top 80×80 of
`idle.png` (8px in from the left), so editing the resting pose changes the small cat too.

### Adding a new cat

If you have a large artwork sheet (AI-generated or otherwise), `swift scripts/import-cat-art.swift <coat>
--walk-right … --walk-left … --groom …` produces the four files above to spec. Then build → test → the name in
`CatNames.swift` and the adoption-box tier in `store-catalog.json`, in that order. For the step-by-step checklist
follow **Adding a new cat** in `AGENTS.md`. If you can draw 96px frames directly, copying an existing coat folder and
drawing over it works too.

## Room backgrounds: `rooms/<theme>/`

The `wall` and `floor` sources. These are free-size originals: the script scales and crops them to the card width
(840pt).

```bash
swift scripts/import-room-art.swift wall  art-src/rooms/<theme>/wall.png  <theme> [top]
swift scripts/import-room-art.swift floor art-src/rooms/<theme>/floor.png <theme> [top]
```

The output is `app/TokenCats/Resources/RoomArt/room-<theme>-wall.png` and `-floor.png` (1x and @2x). A new theme also
goes into `Resources/room-themes.json` (colours) and `store-catalog.json` (price).

## Menu bar icon: `menubar/cat-face.png`

One black cat face on a transparent background. Areas meant to stay empty, such as the inside of the ears and the eyes,
are left transparent. `swift scripts/build-menubar-icon.swift` squares the drawing area and produces the 18px and 36px
template images (`MenuBarIcon.imageset`); macOS paints them white on a dark menu bar and black on a light one.
