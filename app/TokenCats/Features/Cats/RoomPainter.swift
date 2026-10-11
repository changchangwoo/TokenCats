import SwiftUI

/// Draws the cat room into a canvas. The live notch room and the store's still previews share it, so a preview
/// looks exactly like the room it promises.
@MainActor
enum RoomPainter {
    static func cat(_ cat: CatSceneCat, in graphics: GraphicsContext, baseline: Double) {
        let sprites = CatSprites.shared
        let rect = CGRect(x: cat.x - 48, y: baseline - 94, width: 96, height: 96)
        if let petFrame = cat.petFrame, let image = sprites.frame(clip: "pet", index: petFrame, coat: cat.coat) {
            graphics.draw(Image(decorative: image, scale: 1).interpolation(.none), in: rect)
        } else if let image = sprites.frame(clip: cat.clip.rawValue, index: cat.clipIndex, coat: cat.coat) {
            graphics.draw(Image(decorative: image, scale: 1).interpolation(.none), in: rect)
        }
    }

    static func hearts(
        in graphics: GraphicsContext, size: CGSize, catX: Double, baseline: Double,
        progress: Double, side: CatHeartSide
    ) {
        let rows = [".XX.XX.", "XXXXXXX", "XXXXXXX", ".XXXXX.", "..XXX..", "...X..."]
        let direction = side == .left ? -1.0 : 1.0
        let centerX = min(size.width - 14, max(14, catX + direction * 37))
        let left = (centerX - 7).rounded()
        let top = (baseline - 69 - progress * 16).rounded()
        var pixels = Path()
        for (row, line) in rows.enumerated() {
            for (column, mark) in line.enumerated() where mark == "X" {
                pixels.addRect(CGRect(x: left + Double(column * 2), y: top + Double(row * 2),
                                      width: 2, height: 2))
            }
        }
        graphics.fill(pixels, with: .color(Color(red: 0.96, green: 0.28, blue: 0.46).opacity(1 - progress)))
    }

    /// The wall calendar with its top-left corner at (`left`, `calendar.top`).
    static func calendar(_ calendar: CalendarProp, in graphics: GraphicsContext, left: Double) {
        let pixel = CalendarProp.pixel
        for rect in calendar.rects {
            graphics.fill(Path(CGRect(x: left + Double(rect.x) * pixel, y: calendar.top + Double(rect.y) * pixel,
                                      width: Double(rect.width) * pixel, height: Double(rect.height) * pixel)),
                          with: .color(rect.color.swiftUI))
        }
    }

    /// Wall and floor fills, the background's pictures, the floor's edge, the calendar, the floor shadow, then the
    /// floor props; cats are drawn after this. A missing picture leaves its fill showing (or its prop out).
    static func scene(_ scene: CatRoomScene, in graphics: GraphicsContext, size: CGSize) {
        func fill(_ band: SceneBand) {
            graphics.fill(Path(CGRect(x: 0, y: band.top, width: size.width, height: band.height)),
                          with: .color(band.color.swiftUI))
        }
        scene.bands.prefix(CatRoomScene.artLayer).forEach(fill)
        if let art = scene.art, let rects = scene.artRects(width: size.width) {
            for (rect, name) in [(rects.wall, art.wall), (rects.floor, art.floor)] {
                guard let image = RoomArtImages.image(name) else { continue }
                graphics.draw(Image(nsImage: image).resizable(),
                              in: CGRect(x: rect.x, y: rect.y, width: rect.width, height: rect.height))
            }
        }
        scene.bands.dropFirst(CatRoomScene.artLayer).forEach(fill)
        if let calendar = scene.calendarProp {
            Self.calendar(calendar, in: graphics, left: calendar.left(inWidth: size.width))
        }
        let shadow = scene.shadow
        graphics.fill(Path(ellipseIn: CGRect(x: shadow.inset, y: shadow.top,
                                             width: size.width - shadow.inset * 2, height: shadow.height)),
                      with: .color(shadow.color.swiftUI))
        for placed in scene.propRects(width: size.width) {
            guard let name = placed.prop.art?.image, let image = RoomArtImages.image(name) else { continue }
            let rect = placed.rect
            graphics.draw(Image(nsImage: image).resizable().interpolation(.none),
                          in: CGRect(x: rect.x, y: rect.y, width: rect.width, height: rect.height))
        }
    }
}
