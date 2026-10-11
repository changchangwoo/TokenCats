# App icon

A close-up of the in-game black cat, used as is, on a sky-blue gradient (`#9DDCFF → #3E8FE0`). Settled on 2026-10-11.
The black cat is the first cat TokenCats ever made, which is why it stands for the app.
The background was chosen after comparing the eye colour (yellow-green) and cream; sky blue sits quietly next to the
default macOS accent colour and feels like a Mac app. After the app's interior switched to the cozy-room palette,
cream, brown and the room picture were compared as backgrounds too, but sky blue stayed (2026-10-11). The app is
normally not in the Dock, so the icon and the room are rarely seen side by side; instead the first cat is fixed to
black so the cat on the icon walks into the room.

- Source: `black-idle-96.png` — the sitting frame taken as is from `art-src/cats/black/idle.png`
  (feat/notch-companion-mvp). Not edited.
- How it is made: `swift scripts/build-app-icon.swift`
  - Drawn on a 1024 canvas at an integer scale of 10×. The ear tips (frame row 6) sit 196px from the top, and the
    midpoint between the eyes (column 44.5) is centred.
  - The tail is erased: from row 58, everything beyond the first empty pixel to the right of the body is cleared, and
    on the rows where the tail joins the body the clearing starts at column 67 (column 66 from row 87).
  - Follows the macOS icon grid (body 832/1024, corner radius 22.5%); the smaller sizes are downscaled from the 1024
    picture.
  - The square of the same composition (`docs/design/app-icon-square-1024.png`) is the GitHub App logo.
  - The repository social preview (`docs/design/social-preview-1280x640.png`) centres the full sitting cat, tail and
    all, at 6×.
- When the black cat's art changes, extract the frame again, replace this source and re-run the script. If the tail
  moved, check the script's `tail` values as well.
- At 16px the eyes blur. That size only appears in Finder list view, so it is left as is for now.
