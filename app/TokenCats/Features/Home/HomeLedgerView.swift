import SwiftUI

/// The ledger under Home's room: churu on hand, the agents' limits, then the usage record. Each section has a
/// fixed height (`HomeLayout`) so the notch can size itself before the numbers arrive.
struct HomeLedgerView: View {
    let theme: RoomTheme
    let display: HomeDisplaySettings
    @ObservedObject private var limits = UsageLimitsModel.shared
    @AppStorage(AppSettings.Key.missionsExpanded) private var missionsExpanded = AppSettings.Default.missionsExpanded

    var body: some View {
        let sections = HomeLayout.sections(for: display)
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(sections.enumerated()), id: \.offset) { index, section in
                if index > 0 {
                    Rectangle()
                        .fill(theme.panelHighlight.swiftUI.opacity(0.45))
                        .frame(height: 1)
                        .padding(.vertical, (HomeLayout.dividerHeight - 1) / 2)
                }
                Group {
                    switch section {
                    case .balance: HomeBalanceSection(theme: theme, display: display)
                    case .missions: HomeMissionsSection(theme: theme)
                    case .limits: UsageDashboardView(theme: theme, display: display)
                    case .history: HomeHistorySection(theme: theme, display: display)
                    }
                }
                .frame(height: HomeLayout.height(of: section, expanded: missionsExpanded,
                                                 limitRows: limits.visibleLimitRows(for: display)), alignment: .top)
                .animation(.smooth(duration: 0.25), value: missionsExpanded)
            }
        }
        .foregroundStyle(theme.ink.swiftUI)
    }
}

/// Section title used across the ledger.
struct HomeLedgerTitle: View {
    let text: LocalizedStringKey

    var body: some View {
        Text(text).font(.system(size: 12, weight: .semibold, design: .rounded))
    }
}

/// Churu on hand, with the adoption box one tap away.
struct HomeBalanceSection: View {
    let theme: RoomTheme
    let display: HomeDisplaySettings
    @ObservedObject private var churu = ChuruModel.shared
    @ObservedObject private var store = StoreModel.shared

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            if display.showBalance {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Image(systemName: "fish.fill").foregroundStyle(theme.accent.swiftUI)
                        Text("Churu balance").opacity(0.75)
                    }
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        LoadingValue(text: churu.snapshot.map { TokenCount.compact($0.balance) })
                            .font(.system(size: 22, weight: .heavy, design: .rounded))
                            .monospacedDigit()
                            .help("Churu earned since the app was installed")
                        Text("churu").font(.system(size: 11, weight: .semibold, design: .rounded)).opacity(0.8)
                    }
                }
            }
            Spacer(minLength: 0)
            if display.showAdoptionProgress, let price = store.catalog?.catBox.price {
                adoptionButton(price: price)
            }
        }
    }

    private func adoptionButton(price: Int) -> some View {
        // No bar until the balance is known, so it never shows an empty box that suddenly fills.
        let progress = churu.snapshot.flatMap { $0.balance < price ? $0.progress(toward: price) : nil }
        return Button {
            store.route = .adopt
            withAnimation(.smooth) { NotchCoordinator.shared.currentView = .store }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("Open adoption box").font(.system(size: 12, weight: .semibold, design: .rounded))
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(theme.accent.swiftUI)
                }
                if let progress {
                    AdoptionProgressBar(progress: progress, theme: theme)
                        .help("\(TokenCount.compact(churu.snapshot?.balance ?? 0)) / \(TokenCount.compact(price)) churu")
                        .transition(.opacity)
                }
            }
            .fixedSize()
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 8).fill(theme.surface.swiftUI))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open adoption box")
    }
}

/// The balance's way toward the next box. It fills from empty when it first appears, then follows the balance.
private struct AdoptionProgressBar: View {
    let progress: Double
    let theme: RoomTheme
    @State private var shown = 0.0

    var body: some View {
        Capsule().fill(theme.levels[0].swiftUI)
            .overlay(alignment: .leading) {
                GeometryReader { geometry in
                    Capsule().fill(theme.accent.swiftUI).frame(width: geometry.size.width * shown)
                }
            }
            .frame(height: 3)
            .onAppear { withAnimation(.smooth(duration: 0.6)) { shown = progress } }
            .onChange(of: progress) { _, new in withAnimation(.smooth(duration: 0.6)) { shown = new } }
    }
}

/// Today and the last seven days side by side, with the streak and a way into Statistics.
struct HomeHistorySection: View {
    let theme: RoomTheme
    let display: HomeDisplaySettings
    @ObservedObject private var churu = ChuruModel.shared
    @ObservedObject private var history = HomeUsageHistoryModel.shared
    @ObservedObject private var cost = CostUsageModel.shared
    @ObservedObject private var coordinator = NotchCoordinator.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                HomeLedgerTitle(text: "Usage history")
                Spacer(minLength: 0)
                if display.showStreak, let streak = churu.snapshot?.streakDays, streak > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "flame").foregroundStyle(theme.accent.swiftUI)
                        Text("\(streak) day streak")
                    }
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .opacity(0.85)
                }
                Button {
                    withAnimation(.smooth(duration: 0.28)) { coordinator.currentView = .statistics }
                } label: {
                    HStack(spacing: 3) {
                        Text("Details")
                        Image(systemName: "chevron.right").imageScale(.small)
                    }
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .opacity(0.8)
                }
                .buttonStyle(.plain)
            }
            HStack(alignment: .top, spacing: 0) {
                if display.showTodayTokens || display.showEstimatedCost {
                    column("Today", tokens: cost.snapshot?.todayTotal.tokens ?? churu.snapshot?.todayTokens,
                           cost: cost.snapshot?.todayTotal.estimate.label, showsTokens: display.showTodayTokens)
                }
                if (display.showTodayTokens || display.showEstimatedCost) && display.showWeeklyTokens {
                    Rectangle().fill(theme.panelHighlight.swiftUI.opacity(0.45)).frame(width: 1, height: 36)
                        .padding(.horizontal, 14)
                }
                if display.showWeeklyTokens {
                    column("Last 7 days", tokens: cost.snapshot?.weekTotal.tokens ?? history.week?.total,
                           cost: cost.snapshot?.weekTotal.estimate.label, showsTokens: true)
                }
            }
        }
        .task(id: churu.snapshot?.todayTokens) {
            history.refresh(day: churu.snapshot?.day ?? ChuruLedger.dayKey(Date(), .current),
                            todayTokens: churu.snapshot?.todayTokens ?? 0)
        }
    }

    private func column(_ label: LocalizedStringKey, tokens: Int?, cost: String?, showsTokens: Bool) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(.system(size: 10, weight: .medium, design: .rounded)).opacity(0.7)
            if showsTokens {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    LoadingValue(text: tokens.map(TokenCount.compact))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text("tokens").font(.system(size: 10, weight: .semibold, design: .rounded)).opacity(0.8)
                }
            }
            if display.showEstimatedCost {
                LoadingValue(text: cost)
                    .font(.system(size: 10, design: .rounded))
                    .monospacedDigit()
                    .opacity(0.7)
                    .help(CostEstimate.explanation)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
