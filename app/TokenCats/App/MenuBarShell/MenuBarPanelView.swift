import SwiftUI

/// The open notch's screens in a dark panel under the menu bar icon: the same header and tab content in the same
/// box (`vm.notchSize`), so every tab gets the room it has in the notch. Content exists only while the panel is
/// shown (`vm.notchState == .open`), so the room stops animating when it closes, as it does in the notch.
struct MenuBarPanelView: View {
    /// The notch's header row is as tall as the closed notch; the panel has none, so it takes a typical one.
    static let headerHeight: CGFloat = 32

    @EnvironmentObject var vm: NotchViewModel
    @ObservedObject var coordinator = NotchCoordinator.shared

    var body: some View {
        VStack(spacing: 0) {
            if vm.notchState == .open {
                VStack(alignment: .leading, spacing: 0) {
                    NotchHeader(showsNotchMask: false)
                        .frame(height: Self.headerHeight)
                    CompanionTabContent()
                }
                .padding([.horizontal, .bottom], 12)
                .frame(width: vm.notchSize.width, height: vm.notchSize.height, alignment: .top)
                .background(.black)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: .black.opacity(0.5), radius: 8, y: 4)
            }
        }
        .frame(width: MenuBarPanel.size.width, height: MenuBarPanel.size.height, alignment: .top)
        .onChange(of: coordinator.currentView) { _, view in
            if vm.notchState == .open {
                withAnimation(.smooth(duration: 0.25)) { vm.notchSize = openNotchSize(for: view) }
            }
        }
        .preferredColorScheme(.dark)
        .environmentObject(vm)
    }
}
