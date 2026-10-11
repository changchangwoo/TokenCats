import SwiftUI

/// Closed notch: the cats living in the room sit beside it, two on each wing, drawn from the same sitting picture
/// as the store. The closed notch knows nothing about agent sessions.
/// Both wings take the same width so the notch rectangle stays on the physical notch.
struct ClosedNotchView: View {
    static let slotSpacing: CGFloat = 2

    @EnvironmentObject var vm: NotchViewModel
    @ObservedObject private var store = StoreModel.shared

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
        HStack {
            wingView(wings.left, cats: cats, size: side)
                .frame(width: wing, alignment: .trailing)

            Rectangle()
                .fill(.black)
                .frame(width: vm.closedNotchSize.width - 20)

            wingView(wings.right, cats: cats, size: side)
                .frame(width: wing, alignment: .leading)
        }
        .frame(height: vm.effectiveClosedNotchHeight, alignment: .center)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(cats.count) cats in the room")
    }

    private func wingView(_ ids: [String], cats: [CatResidentRecord], size: CGFloat) -> some View {
        HStack(spacing: Self.slotSpacing) {
            ForEach(ids, id: \.self) { id in
                if let cat = cats.first(where: { $0.id == id }) {
                    if let image = CatSprites.shared.portrait(coat: cat.coat) {
                        Image(decorative: image, scale: 1)
                            .interpolation(.none)
                            .resizable()
                            .frame(width: size, height: size)
                    }
                }
            }
        }
    }
}
