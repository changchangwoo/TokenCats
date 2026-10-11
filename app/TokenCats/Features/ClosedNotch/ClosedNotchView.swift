import SwiftUI

/// Closed notch: the cats living in the room sit beside it, two on each wing, drawn from the same sitting picture
/// as the store.
/// With session alerts on (Settings › 닫힌 노치, off by default), a waiting session marks a cat with a dot; tapping
/// that cat jumps to its terminal.
/// Both wings take the same width so the notch rectangle stays on the physical notch.
struct ClosedNotchView: View {
    static let slotSpacing: CGFloat = 2

    @EnvironmentObject var vm: NotchViewModel
    @ObservedObject private var store = StoreModel.shared
    @ObservedObject private var hub = AgentHub.shared
    @AppStorage(AppSettings.Key.sessionAlerts) private var sessionAlerts = AppSettings.Default.sessionAlerts

    /// Width of one wing; ContentView uses it to size the notch chin, so both must agree.
    static func wingWidth(iconSize: CGFloat, count: Int) -> CGFloat {
        let slots = ClosedNotchCats.wingSlots(count: count)
        return slots == 0 ? 0 : CGFloat(slots) * iconSize + CGFloat(slots - 1) * slotSpacing
    }

    /// The room's cats that have art, in room order.
    @MainActor static func cats(in household: CatHousehold) -> [CatResidentRecord] {
        household.roomResidents.filter { CatSprites.shared.hasArt(coat: $0.coat) }
    }

    var body: some View {
        let side = CGFloat(ClosedNotchCats.iconSize(notchHeight: vm.effectiveClosedNotchHeight))
        let cats = Self.cats(in: store.household)
        let wings = ClosedNotchCats.split(cats.map(\.id))
        let wing = Self.wingWidth(iconSize: side, count: cats.count)
        let alerts = sessionAlerts ? ClosedNotchCats.alerts(sessions: hub.waitingSessions, cats: cats.map(\.id))
                                   : ClosedNotchCats.Alerts(byCat: [:], overflow: 0)
        HStack {
            wingView(wings.left, cats: cats, size: side, alerts: alerts)
                .frame(width: wing, alignment: .trailing)

            Rectangle()
                .fill(.black)
                .frame(width: vm.closedNotchSize.width - 20)

            wingView(wings.right, cats: cats, size: side, alerts: alerts)
                .frame(width: wing, alignment: .leading)
        }
        .frame(height: vm.effectiveClosedNotchHeight, alignment: .center)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(cats.count) cats in the room")
    }

    private func wingView(_ ids: [String], cats: [CatResidentRecord], size: CGFloat,
                          alerts: ClosedNotchCats.Alerts) -> some View {
        HStack(spacing: Self.slotSpacing) {
            ForEach(ids, id: \.self) { id in
                if let cat = cats.first(where: { $0.id == id }) {
                    if let image = CatSprites.shared.portrait(coat: cat.coat) {
                        Image(decorative: image, scale: 1)
                            .interpolation(.none)
                            .resizable()
                            .frame(width: size, height: size)
                            .overlay(alignment: .topTrailing) {
                                if let slot = alerts.byCat[id] { alertDot(slot) }
                            }
                            .overlay(alignment: .bottomTrailing) {
                                if alerts.overflow > 0, id == cats.last?.id {
                                    Text("+\(alerts.overflow)")
                                        .font(.system(size: 7, weight: .bold, design: .rounded))
                                        .foregroundStyle(.white)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                guard let slot = alerts.byCat[id] else { return }
                                let terminal = hub.sessions.first { $0.id == slot.id }?.orcaTerminal
                                jump(to: slot.id, terminal: terminal, notice: .constant(nil))
                            }
                    }
                }
            }
        }
    }
}

extension ClosedNotchView {
    /// Orange: needs approval, red: error, white: a finished turn not yet seen. Other waiting states show nothing.
    @ViewBuilder
    fileprivate func alertDot(_ slot: NotchSlot) -> some View {
        switch slot.mood {
        case .needsApproval: Circle().fill(.orange).frame(width: 6, height: 6)
        case .error: Circle().fill(.red).frame(width: 6, height: 6)
        default: if slot.unseen { Circle().fill(.white).frame(width: 5, height: 5) }
        }
    }
}
