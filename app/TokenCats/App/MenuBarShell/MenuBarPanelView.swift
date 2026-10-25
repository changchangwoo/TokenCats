import SwiftUI

/// The open notch's screens in a menu bar window: the same header and tab content in the same box (`vm.notchSize`),
/// so every tab gets the room it has in the notch, with the rounded corners and hairline edge of a system menu bar
/// window. Content exists only while the panel is shown (`vm.notchState == .open`), so the room stops animating
/// when it closes, as it does in the notch.
struct MenuBarPanelView: View {
    /// The notch's header row is as tall as the closed notch; the panel has none, so it takes a typical one.
    static let headerHeight: CGFloat = 32
    static let cornerRadius: CGFloat = 12

    @EnvironmentObject var vm: NotchViewModel
    @ObservedObject var coordinator = NotchCoordinator.shared

    var body: some View {
        VStack(spacing: 0) {
            if vm.notchState == .open {
                RevealingPanel(size: vm.notchSize)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onChange(of: coordinator.currentView) { _, view in
            if vm.notchState == .open {
                withAnimation(.smooth(duration: 0.25)) { vm.notchSize = openNotchSize(for: view) }
            }
        }
        .preferredColorScheme(.dark)
    }
}

/// The panel itself. Each time it is shown it unrolls from the menu bar the way the notch opens: it starts as tall
/// as the tab row and springs down to its full height, top edge fixed, the content uncovered from the top.
private struct RevealingPanel: View {
    let size: CGSize
    @State private var revealed = false

    /// The notch's opening spring (`ContentView`).
    private static let openAnimation = Animation.spring(response: 0.42, dampingFraction: 0.8, blendDuration: 0)

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: MenuBarPanelView.cornerRadius, style: .continuous)
        VStack(alignment: .leading, spacing: 0) {
            NotchHeader(showsNotchMask: false)
                .frame(height: MenuBarPanelView.headerHeight)
            CompanionTabContent()
                .opacity(revealed ? 1 : 0)
        }
        .padding([.horizontal, .bottom], 12)
        .frame(width: size.width, height: size.height, alignment: .top)
        // The box grows over the full-size content, so it is uncovered from the top rather than squeezed.
        .frame(height: revealed ? size.height : MenuBarPanelView.headerHeight + 12, alignment: .top)
        .background(.black)
        .clipShape(shape)
        .overlay(shape.strokeBorder(.white.opacity(0.14), lineWidth: 0.5))
        .onAppear {
            withAnimation(Self.openAnimation) { revealed = true }
        }
    }
}
