import Combine
import SwiftUI

/// The cats' room, visible even when no agent sessions are running. Up to `CatHousehold.roomCapacity` cats share it.
struct CatRoomView: View {
    let theme: RoomTheme
    private let stage = CatRoomStage.shared
    @ObservedObject private var churu = ChuruModel.shared
    // Observed so a quality or power change re-times the room.
    @ObservedObject private var battery = BatteryStatusViewModel.shared
    @AppStorage(AppSettings.Key.animationQuality) private var quality = AppSettings.Default.animationQuality
    @AppStorage(AppSettings.Key.batterySaver) private var batterySaver = AppSettings.Default.batterySaver
    @ObservedObject private var store = StoreModel.shared

    var body: some View {
        GeometryReader { geometry in
            TimelineView(.animation(minimumInterval: 1.0 / AppSettings.power.quality.framesPerSecond)) { context in
                let baseline = geometry.size.height - 18
                let cats = stage.tick(at: context.date, width: geometry.size.width)
                ZStack {
                    Canvas { graphics, size in
                        RoomPainter.scene(stage.scene(height: size.height, calendar: churu.wallCalendar,
                                                      theme: theme, decor: store.inventory.decor),
                                          in: graphics, size: size)
                        for cat in cats {
                            RoomPainter.cat(cat, in: graphics, baseline: baseline)
                        }
                        for cat in cats {
                            if let progress = cat.heartProgress {
                                RoomPainter.hearts(in: graphics, size: size, catX: cat.x, baseline: baseline,
                                                   progress: progress, side: cat.heartSide)
                            }
                        }
                    }
                    CatInteractionSurface(
                        catHitRects: cats.map {
                            CGRect(x: $0.x - 52, y: baseline - 94,
                                   width: 104, height: 92)
                        },
                        onPetStart: { point in stage.pet(at: Date(), point: point, baseline: baseline) },
                        onPetMove: { point in stage.pet(at: Date(), point: point, baseline: baseline) },
                        onPetEnd: { stage.endPet(at: Date()) })
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .overlay(alignment: .topTrailing) {
                    if stage.hiddenCount > 0 {
                        Text("+\(stage.hiddenCount)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(Capsule().fill(.black.opacity(0.55)))
                            .padding(8)
                    }
                }
            }
        }
        .accessibilityLabel("Cat room")
        .onDisappear {
            stage.endPet(at: Date())
            stage.pause()
        }
    }
}
