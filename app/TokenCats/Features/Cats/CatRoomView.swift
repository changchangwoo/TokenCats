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
    @ObservedObject private var bonds = CatBondModel.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var notice = Notice()

    var body: some View {
        GeometryReader { geometry in
            TimelineView(.animation(minimumInterval: 1.0 / AppSettings.power.quality.framesPerSecond)) { context in
                let baseline = geometry.size.height - 18
                let cats = stage.tick(at: context.date, width: geometry.size.width)
                let hovered = stage.hoverPoint.flatMap { stage.catID(at: $0, baseline: baseline) }
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
                        onPetStart: { point in
                            stage.pet(at: Date(), point: point, baseline: baseline)
                            Task { await ChuruModel.shared.record(.pet) }
                        },
                        onPetMove: { point in stage.pet(at: Date(), point: point, baseline: baseline) },
                        onPetEnd: { stage.endPet(at: Date()) },
                        onHover: { point in stage.hoverPoint = point },
                        contextMenu: { point in
                            guard let id = stage.catID(at: point, baseline: baseline),
                                  let price = store.catalog?.treatPrice,
                                  bonds.level(of: id) < CatBondRules.maxLevel else { return [] }
                            let priceText = AppLanguage.shared.string(StoreFormat.churu(price))
                            return [RoomMenuItem(title: AppLanguage.shared.string("Give churu · \(priceText)")) {
                                Task { await giveTreat(to: id) }
                            }]
                        })
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .overlay {
                    if let hovered, let cat = cats.first(where: { $0.id == hovered }) {
                        // One badge per cat (`id`): moving to another cat fades a new badge in there instead of
                        // sliding this one across the room.
                        BondBadge(level: bonds.level(of: hovered), progress: bonds.progress(of: hovered), theme: theme)
                            .position(x: min(max(cat.x, 60), geometry.size.width - 60), y: baseline - 108)
                            .allowsHitTesting(false)
                            .transition(reduceMotion ? .identity : .opacity)
                            .id(hovered)
                    }
                }
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.15), value: hovered)
                .overlay(alignment: .topTrailing) {
                    HStack(spacing: 6) {
                        if let message = notice.message {
                            badge { Text(message) }.transition(.opacity)
                        }
                        // Battery saver has taken the room down to its saver rate: say so, or the slow room looks broken.
                        if !AppSettings.power.smallAnimations {
                            badge { Label("Power saving", systemImage: "leaf.fill").labelStyle(.titleAndIcon) }
                        }
                        if stage.hiddenCount > 0 {
                            badge { Text("+\(stage.hiddenCount)") }
                        }
                    }
                    .padding(8)
                }
            }
        }
        .accessibilityLabel("Cat room")
        .animation(.easeInOut(duration: 0.2), value: AppSettings.power.smallAnimations)
        .onDisappear {
            stage.hoverPoint = nil
            stage.endPet(at: Date())
            stage.pause()
        }
    }

    /// One treat: the cat floats hearts, and the badge (if the pointer is still on it) fills.
    private func giveTreat(to id: String) async {
        switch await store.purchase(.treat(catID: id)) {
        case .treated:
            stage.celebrate(id: id, at: Date())
        case .insufficient(let short):
            notice.show("Not enough churu · \(TokenCount.compact(short)) short")
        case .alreadyOwned:
            notice.show("Already at Lv.\(CatBondRules.maxLevel)")
        default:
            notice.show("Could not give churu. Please try again")
        }
    }

    /// A small dark capsule in the room's corner.
    private func badge<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(Capsule().fill(.black.opacity(0.55)))
    }
}
