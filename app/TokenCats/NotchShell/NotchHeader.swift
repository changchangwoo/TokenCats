// NotchShell — adapted from boring.notch (TheBoredTeam, GPL-3.0). See NOTICE.md.
import Defaults
import SwiftUI

/// The open notch's top row: Home/Stats tabs on the left, the cats, store and settings buttons on the right,
/// with a black mask over the physical notch between them.
struct NotchHeader: View {
    @EnvironmentObject var vm: NotchViewModel
    @ObservedObject var coordinator = NotchCoordinator.shared
    /// Off in the menu bar panel: there is no physical notch to cover, and the settings gear always shows because
    /// the "Settings icon in the notch" switch lives on the Notch page, which menu bar mode hides.
    var showsNotchMask: Bool = true

    var body: some View {
        HStack(spacing: 0) {
            HStack {
                TabSelectionView()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .opacity(vm.notchState == .closed ? 0 : 1)
            .blur(radius: vm.notchState == .closed ? 20 : 0)
            .zIndex(2)

            if showsNotchMask && vm.notchState == .open {
                Rectangle()
                    .fill(NSScreen.screen(withUUID: coordinator.selectedScreenUUID)?.safeAreaInsets.top ?? 0 > 0 ? .black : .clear)
                    .frame(width: vm.closedNotchSize.width)
                    .mask { NotchShape() }
            }

            HStack(spacing: 4) {
                if vm.notchState == .open {
                    headerButton("pawprint.fill", label: "Collection", view: .cats)
                    headerButton("cart.fill", label: "Store", view: .store)
                    if Defaults[.settingsIconInNotch] || !showsNotchMask {
                        Button {
                            DispatchQueue.main.async { SettingsWindowController.shared.showWindow() }
                        } label: {
                            capsuleIcon("gear", tint: .white)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Settings")
                    }
                }
            }
            .font(.system(.headline, design: .rounded))
            .frame(maxWidth: .infinity, alignment: .trailing)
            .opacity(vm.notchState == .closed ? 0 : 1)
            .blur(radius: vm.notchState == .closed ? 20 : 0)
            .zIndex(2)
        }
        .foregroundColor(.gray)
        .environmentObject(vm)
    }

    /// A companion screen's toggle: opens `view`, or returns Home when it is already open.
    private func headerButton(_ icon: String, label: LocalizedStringKey, view: NotchViews) -> some View {
        Button {
            withAnimation(.smooth) {
                if view == .store { StoreModel.shared.route = .main }
                coordinator.currentView = coordinator.currentView == view ? .home : view
            }
        } label: {
            capsuleIcon(icon, tint: coordinator.currentView == view ? .white : .gray)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func capsuleIcon(_ name: String, tint: Color) -> some View {
        Capsule()
            .fill(.black)
            .frame(width: 30, height: 30)
            .overlay { Image(systemName: name).foregroundColor(tint).padding().imageScale(.medium) }
    }
}
