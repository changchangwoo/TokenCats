import SwiftUI

/// One frame of the first-run scene (`FirstRunTimeline`): the user's room in the open notch and the first cat.
struct FirstRunScene: View {
    let theme: RoomTheme
    let coat: String
    /// Nil before the cat walks in.
    var cat: FirstRunTimeline.Pose?

    static let size = CGSize(width: 640, height: 190)
    private static let roomHeight = 150.0

    var body: some View {
        Canvas { graphics, size in
            let room = CGRect(x: 12, y: 8, width: size.width - 24, height: Self.roomHeight)
            graphics.translateBy(x: room.minX, y: room.minY)
            graphics.clip(to: Path(roundedRect: CGRect(origin: .zero, size: room.size), cornerRadius: 14))
            RoomPainter.scene(CatRoomScene(height: room.height, calendarTop: 12, calendar: ChuruCalendar.empty(containing: Date(), calendar: .current), theme: theme,
                                           showsCalendar: false),
                              in: graphics, size: room.size)
            if let cat {
                RoomPainter.cat(CatSceneCat(id: "first", coat: coat, x: cat.x, yOffset: 0, clip: cat.clip,
                                            clipIndex: cat.index, petFrame: nil, heartProgress: nil, heartSide: .right),
                                in: graphics, baseline: room.height - 18)
            }
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .background(UnevenRoundedRectangle(bottomLeadingRadius: 24, bottomTrailingRadius: 24).fill(.black))
        .overlay(alignment: .topLeading) {
            if let cat, cat.saysHi {
                Text("Hi!")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(theme.panel.swiftUI)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Capsule().fill(theme.ink.swiftUI))
                    .offset(x: 12 + cat.x + 34, y: 8 + Self.roomHeight - 18 - 100)
            }
        }
    }
}

/// The scene played in the notch on first launch: the notch unfolds from its closed width onto the room, the cat
/// plays its beats, then the notch folds back up and `onFinish` runs.
struct FirstRunAnimation: View {
    let theme: RoomTheme
    let coat: String
    /// Where the unfolding starts: the closed notch's width.
    let closedWidth: CGFloat
    let onFinish: () -> Void
    @State private var start = Date()
    @State private var unfolded = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { context in
            FirstRunScene(theme: theme, coat: coat, cat: FirstRunTimeline.pose(at: context.date.timeIntervalSince(start)))
                .opacity(unfolded ? 1 : 0)
        }
        .frame(width: FirstRunScene.size.width, height: FirstRunScene.size.height)
        .frame(width: unfolded ? FirstRunScene.size.width : closedWidth, height: unfolded ? FirstRunScene.size.height : 0,
               alignment: .top)
        .clipped()
        .task {
            start = Date()
            // The same spring the notch opens with, so the first open feels like every later one.
            withAnimation(.spring(response: 0.42, dampingFraction: 0.8)) { unfolded = true }
            try? await Task.sleep(for: .seconds(FirstRunTimeline.duration))
            withAnimation(.spring(response: 0.45, dampingFraction: 1.0)) { unfolded = false }
            try? await Task.sleep(for: .seconds(FirstRunTimeline.foldDuration))
            onFinish()
        }
    }
}

/// The scene's six beats side by side, for the design document.
struct FirstRunStoryboard: View {
    let theme: RoomTheme
    let coat: String

    static let beats: [FirstRunTimeline.Pose?] = [
        0.2, FirstRunTimeline.walkStart + 0.3, FirstRunTimeline.walkEnd - 0.6, FirstRunTimeline.walkEnd + 0.2,
        FirstRunTimeline.groomStart + 0.5, FirstRunTimeline.duration - 0.1,
    ].map(FirstRunTimeline.pose(at:))
    static let size = CGSize(width: 2 * FirstRunScene.size.width + 3 * 24,
                             height: 3 * (FirstRunScene.size.height + 36) + 4 * 24)

    var body: some View {
        Grid(horizontalSpacing: 24, verticalSpacing: 24) {
            ForEach(0..<3, id: \.self) { row in
                GridRow {
                    ForEach(0..<2, id: \.self) { column in
                        let beat = row * 2 + column
                        VStack(alignment: .leading, spacing: 10) {
                            FirstRunScene(theme: theme, coat: coat, cat: Self.beats[beat])
                            Text(verbatim: "\(beat + 1)")
                                .font(.system(size: 16, weight: .heavy, design: .rounded))
                                .foregroundStyle(theme.accent.swiftUI)
                        }
                    }
                }
            }
        }
        .padding(24)
        .frame(width: Self.size.width, height: Self.size.height)
        .background(Color(white: 0.16))
    }
}
