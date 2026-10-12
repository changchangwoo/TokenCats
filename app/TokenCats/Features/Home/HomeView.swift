import SwiftUI

/// Home of the open notch: the room flows into a compact ledger in the same background theme.
/// Sessions are not shown here. Hook connections live in Settings › Agents.
struct HomeView: View {
    @EnvironmentObject private var vm: NotchViewModel
    @AppStorage(AppSettings.Key.roomTheme) private var backgroundID = AppSettings.Default.roomTheme
    @ObservedObject private var store = StoreModel.shared
    @ObservedObject private var uiDisplay = UIDisplayModel.shared
    @AppStorage(AppSettings.Key.unreadDataNoticedAt) private var unreadNoticedAt = 0.0
    @ObservedObject private var updater = AppUpdater.shared
    @AppStorage(AppSettings.Key.missionsExpanded) private var missionsExpanded = AppSettings.Default.missionsExpanded
    /// Data files that could not be read and started fresh since the user last dismissed the notice.
    @State private var unreadFiles: [String] = []
    private var theme: RoomTheme { store.theme(id: backgroundID) }

    var body: some View {
        VStack(spacing: 0) {
            CatRoomView(theme: theme)
                .frame(height: 190)
                .overlay(alignment: .top) {
                    VStack(spacing: 6) {
                        if let version = updater.pendingVersion, !updater.bannerDismissed {
                            UpdateBanner(version: version, theme: theme,
                                         onUpdate: updater.checkForUpdates, onLater: updater.dismissBanner)
                                .transition(.opacity)
                        }
                        if !unreadFiles.isEmpty {
                            UnreadDataBanner(files: unreadFiles, theme: theme) {
                                unreadNoticedAt = Date().timeIntervalSince1970
                                withAnimation(.smooth) { unreadFiles = [] }
                            }
                            .transition(.opacity)
                        }
                    }
                    .padding(8)
                    .animation(.smooth, value: updater.pendingVersion == nil || updater.bannerDismissed)
                }
            if !HomeLayout.sections(for: uiDisplay.settings.home).isEmpty {
                HomeLedgerView(theme: theme, display: uiDisplay.settings.home)
                .padding(.horizontal, 16)
                .padding(.vertical, HomeLayout.ledgerPadding / 2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.panel.swiftUI)
                .overlay(alignment: .top) {
                    VStack(spacing: 0) {
                        theme.panelEdge.swiftUI.frame(height: 3)
                        theme.panelHighlight.swiftUI.frame(height: 1)
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
        .onAppear {
            uiDisplay.reload()
            unreadFiles = UnreadDataReport.files(in: AppPaths.supportDirectory,
                                                 after: Date(timeIntervalSince1970: unreadNoticedAt))
        }
        .task {
            while !Task.isCancelled {
                await ChuruModel.shared.refresh()
                await CostUsageModel.shared.refresh()
                try? await Task.sleep(for: .seconds(60))
            }
        }
        .onChange(of: uiDisplay.settings.home) { _, _ in resizeNotch() }
        // The chevron on the missions section folds it to one line; the notch follows.
        .onChange(of: missionsExpanded) { _, _ in resizeNotch() }
    }
}

extension HomeView {
    private func resizeNotch() {
        if vm.notchState == .open {
            withAnimation(.smooth(duration: 0.25)) { vm.notchSize = openNotchSize(for: .home) }
        }
    }
}

/// A newer version a scheduled check found: one line over the room, and the Update button opens Sparkle's window.
private struct UpdateBanner: View {
    let version: String
    let theme: RoomTheme
    let onUpdate: () -> Void
    let onLater: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.down.circle.fill").foregroundStyle(theme.accent.swiftUI)
            Text("TokenCats \(version) is available.")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
            Spacer(minLength: 4)
            Button("Later", action: onLater)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
            Button("Update", action: onUpdate)
                .font(.system(size: 10, weight: .bold, design: .rounded))
        }
        .foregroundStyle(theme.ink.swiftUI)
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 8).fill(theme.surface.swiftUI))
    }
}

/// "Some data could not be read, so it started fresh", once, with a way to the files kept aside.
private struct UnreadDataBanner: View {
    let files: [String]
    let theme: RoomTheme
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(theme.accent.swiftUI)
            VStack(alignment: .leading, spacing: 2) {
                Text("Some data couldn't be read, so it started fresh: \(files.joined(separator: ", "))")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                Text("The unreadable files are kept in the data folder.")
                    .font(.system(size: 10, design: .rounded)).opacity(0.8)
            }
            Spacer(minLength: 4)
            Button("Open data folder") { NSWorkspace.shared.open(AppPaths.supportDirectory) }
                .font(.system(size: 10, weight: .semibold, design: .rounded))
            Button("Got it", action: onDismiss)
                .font(.system(size: 10, weight: .bold, design: .rounded))
        }
        .foregroundStyle(theme.ink.swiftUI)
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 8).fill(theme.surface.swiftUI))
    }
}
