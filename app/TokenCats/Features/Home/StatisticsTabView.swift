import SwiftUI

/// Detailed history has its own notch tab, leaving Home for quick status checks.
struct StatisticsTabView: View {
    @AppStorage(AppSettings.Key.roomTheme) private var backgroundID = AppSettings.Default.roomTheme
    @ObservedObject private var display = UIDisplayModel.shared
    @ObservedObject private var churu = ChuruModel.shared
    @ObservedObject private var cost = CostUsageModel.shared

    private var theme: RoomTheme { RoomThemeCatalog.bundled.selected(id: backgroundID) }

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 13) {
                if display.settings.home.showsHistory {
                    HomeUsageHistoryView(theme: theme, display: display.settings.home)
                    Rectangle()
                        .fill(theme.panelHighlight.swiftUI.opacity(0.65))
                        .frame(height: 1)
                }
                providerShares
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .background(theme.panel.swiftUI)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .frame(height: statisticsNotchHeight - 40)
        .onAppear { display.reload() }
        .task {
            while !Task.isCancelled {
                await churu.refresh()
                await CostUsageModel.shared.refresh()
                try? await Task.sleep(for: .seconds(60))
            }
        }
    }

    private var providerShares: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Today's usage")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(theme.ink.swiftUI.opacity(0.78))
            if let snapshot = cost.snapshot, snapshot.todayTotal.tokens > 0 {
                HStack(spacing: 20) {
                    ForEach(TokenProvider.allCases, id: \.rawValue) { provider in
                        let usage = snapshot.today[provider] ?? ProviderCostSummary()
                        let share = Int((Double(usage.tokens) / Double(snapshot.todayTotal.tokens) * 100).rounded())
                        HStack(spacing: 6) {
                            Text(provider.rawValue.capitalized)
                                .fontWeight(.semibold)
                            Text("\(TokenCount.compact(usage.tokens)) · \(share)%"
                                 + (display.settings.home.showEstimatedCost ? " · \(usage.estimate.label)" : ""))
                                .foregroundStyle(theme.ink.swiftUI.opacity(0.76))
                                .help(CostEstimate.explanation)
                        }
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(theme.ink.swiftUI)
                    }
                }
            } else {
                Text("Counting today's usage")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(theme.ink.swiftUI.opacity(0.72))
            }
        }
    }
}
