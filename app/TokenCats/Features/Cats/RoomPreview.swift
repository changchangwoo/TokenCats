import SwiftUI

/// A still, scaled-down copy of the notch room in `theme`, with the cats that live in the room standing in it.
/// Used by the store so a background is judged as a place for the user's own cats, not as a colour swatch.
struct RoomPreview: View {
    let theme: RoomTheme
    var showsPreviewBadge = false
    @ObservedObject private var store = StoreModel.shared
    @ObservedObject private var churu = ChuruModel.shared

    private static let size = CGSize(width: CatRoomScene.notchRoomWidth, height: 190)

    var body: some View {
        Canvas { graphics, canvasSize in
            let scale = canvasSize.width / Self.size.width
            graphics.scaleBy(x: scale, y: scale)
            let decor = store.inventory.decor
            let scene = CatRoomScene(height: Self.size.height, calendarTop: 12, calendar: churu.wallCalendar,
                                     theme: theme, showsCalendar: decor.shows(.calendar), props: decor.shownProps)
            RoomPainter.scene(scene, in: graphics, size: Self.size)
            for cat in standingCats { RoomPainter.cat(cat, in: graphics, baseline: Self.size.height - 18) }
        }
        .aspectRatio(Self.size.width / Self.size.height, contentMode: .fit)
        .overlay(alignment: .topTrailing) {
            if showsPreviewBadge {
                Text("Preview")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.previewInk.swiftUI)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Capsule().fill(theme.preview.swiftUI.opacity(0.9)))
                    .padding(6)
            }
        }
        .accessibilityLabel(Text("\(theme.id) room preview" as LocalizedStringResource))
    }

    /// The room's cats where the live room would first place them, in their resting pose.
    private var standingCats: [CatSceneCat] {
        let drawable = CatHousehold(residents: store.household.residents.filter { CatSprites.shared.hasArt(coat: $0.coat) })
        var room = CatRoom(household: drawable)
        return room.step(dt: 0, now: 0, width: Self.size.width)
    }
}
