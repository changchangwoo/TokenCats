import SwiftUI

/// Home of the open notch: the room flows into a compact ledger in the same background theme.
/// Sessions are not shown here. Hook connections live in Settings › Agents.
struct HomeView: View {
    @EnvironmentObject private var vm: NotchViewModel
    @AppStorage(AppSettings.Key.roomTheme) private var backgroundID = AppSettings.Default.roomTheme
    @ObservedObject private var store = StoreModel.shared
    @ObservedObject private var uiDisplay = UIDisplayModel.shared
    @AppStorage(AppSettings.Key.unreadDataNoticedAt) private var unreadNoticedAt = 0.0
    /// Data files that could not be read and started fresh since the user last dismissed the notice.
    @State private var unreadFiles: [String] = []
    private var theme: RoomTheme { store.theme(id: backgroundID) }

    var body: some View {
        VStack(spacing: 0) {
            CatRoomView(theme: theme)
                .frame(height: 190)
                .overlay(alignment: .top) {
                    if !unreadFiles.isEmpty {
                        UnreadDataBanner(files: unreadFiles, theme: theme) {
                            unreadNoticedAt = Date().timeIntervalSince1970
                            withAnimation(.smooth) { unreadFiles = [] }
                        }
                        .padding(8)
                        .transition(.opacity)
                    }
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
        .onChange(of: uiDisplay.settings.home) { _, _ in
            if vm.notchState == .open {
                withAnimation(.smooth(duration: 0.25)) { vm.notchSize = openNotchSize(for: .home) }
            }
        }
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
