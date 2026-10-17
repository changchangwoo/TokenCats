import SwiftUI

/// Detailed history has its own notch tab, leaving Home for quick status checks. A dashboard of cards: today, the
/// last seven days and the streak on top; the week's chart beside the provider split; the year's graph at the bottom,
/// one scroll down.
struct StatisticsTabView: View {
    @AppStorage(AppSettings.Key.roomTheme) private var backgroundID = AppSettings.Default.roomTheme
    @ObservedObject private var display = UIDisplayModel.shared
    @ObservedObject private var churu = ChuruModel.shared
    @ObservedObject private var cost = CostUsageModel.shared
    @ObservedObject private var history = HomeUsageHistoryModel.shared
    /// How far the content runs past the visible area; the ↓ hint shows while it does.
    @State private var hiddenBelow = 0.0

    private var theme: RoomTheme { RoomThemeCatalog.bundled.selected(id: backgroundID) }
    private var settings: HomeDisplaySettings { display.settings.home }

    private var week: WeekUsage? {
        if let snapshot = cost.snapshot {
            return WeekUsage.make(dailyTokens: snapshot.dailyTokens, today: Date(), calendar: .current,
                                  byProvider: snapshot.dailyByProvider)
        }
        return history.week
    }

    var body: some View {
        GeometryReader { viewport in
            let visibleHeight = viewport.size.height
            ScrollViewReader { scroller in
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top, spacing: 10) {
                            todayCard
                            weekCard
                            streakCard
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        if settings.showWeeklyChart || settings.showWeeklyTokens {
                            HStack(alignment: .top, spacing: 10) {
                                if settings.showWeeklyChart {
                                    activityCard
                                }
                                providersCard
                                    .frame(width: settings.showWeeklyChart ? 196 : nil)
                            }
                            .fixedSize(horizontal: false, vertical: true)
                        }
                        if settings.showContributionGraph {
                            journeyCard
                        }
                        Color.clear.frame(height: 0).id(Self.end)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(GeometryReader { content in
                        Color.clear.preference(key: ContentBottom.self,
                                               value: content.frame(in: .named(Self.space)).maxY)
                    })
                }
                .coordinateSpace(name: Self.space)
                .scrollIndicators(.hidden)
                .onPreferenceChange(ContentBottom.self) { bottom in
                    // The action is @Sendable on older SDKs (CI's Xcode 16), so hop to the main actor explicitly.
                    Task { @MainActor in hiddenBelow = bottom - visibleHeight }
                }
                .overlay(alignment: .bottom) {
                    if hiddenBelow > 24 {
                        Button {
                            withAnimation(.smooth(duration: 0.4)) { scroller.scrollTo(Self.end, anchor: .bottom) }
                        } label: {
                            Image(systemName: "arrow.down")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(theme.ink.swiftUI)
                                .frame(width: 26, height: 26)
                                .background(Circle().fill(theme.surface.swiftUI))
                                .overlay(Circle().stroke(theme.panelHighlight.swiftUI.opacity(0.6), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .padding(.bottom, 8)
                        .transition(.opacity)
                        .accessibilityLabel("Scroll down")
                    }
                }
                .animation(.smooth(duration: 0.25), value: hiddenBelow > 24)
            }
        }
        .background(theme.panel.swiftUI)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .frame(height: statisticsNotchHeight - 40)
        .onAppear { display.reload() }
        .task(id: churu.snapshot?.todayTokens) {
            history.refresh(day: churu.snapshot?.day ?? ChuruLedger.dayKey(Date(), .current),
                            todayTokens: churu.snapshot?.todayTokens ?? 0)
        }
        .task {
            while !Task.isCancelled {
                await churu.refresh()
                await CostUsageModel.shared.refresh()
                try? await Task.sleep(for: .seconds(60))
            }
        }
    }

    private static let end = "statistics-end"
    private static let space = "statistics-scroll"

    // MARK: Top row

    private var todayCard: some View {
        StatisticsCard(theme: theme) {
            VStack(alignment: .leading, spacing: 0) {
                caption("Today's usage")
                if let snapshot = cost.snapshot, snapshot.todayTotal.tokens > 0 {
                    figure(TokenCount.compact(snapshot.todayTotal.tokens))
                    if settings.showEstimatedCost {
                        estimate(snapshot.todayTotal.estimate.label)
                    }
                    Spacer(minLength: 10)
                    let shares = ProviderShare.of(snapshot.today)
                    ShareBar(shares: shares, theme: theme)
                    Text(shares.map { "\($0.provider.displayName) \($0.percent)%" }.joined(separator: " · "))
                        .font(.system(size: 9, design: .rounded))
                        .foregroundStyle(theme.ink.swiftUI.opacity(0.7))
                        .padding(.top, 5)
                } else {
                    Text("Counting today's usage")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(theme.ink.swiftUI.opacity(0.72))
                        .padding(.top, 8)
                }
            }
        }
    }

    private var weekCard: some View {
        StatisticsCard(theme: theme) {
            VStack(alignment: .leading, spacing: 0) {
                caption("Last 7 days")
                figure(week.map { TokenCount.compact($0.total) })
                if settings.showEstimatedCost {
                    estimate(cost.snapshot?.weekTotal.estimate.label)
                }
                Spacer(minLength: 10)
                Text("Average per active day")
                    .font(.system(size: 9, design: .rounded))
                    .foregroundStyle(theme.ink.swiftUI.opacity(0.66))
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    LoadingValue(text: history.year.map { TokenCount.compact($0.averagePerActiveDay) })
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text(verbatim: "365d")
                        .font(.system(size: 9, design: .rounded))
                        .foregroundStyle(theme.ink.swiftUI.opacity(0.6))
                }
                .foregroundStyle(theme.ink.swiftUI)
                .padding(.top, 2)
            }
        }
    }

    private var streakCard: some View {
        let streak = history.year?.currentStreak
        return StatisticsCard(theme: theme, tint: true) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    caption("Current streak")
                    Spacer(minLength: 4)
                    Image(systemName: "flame.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(theme.accent.swiftUI)
                }
                figure(streak.map { "\($0)" })
                if let streak {
                    Text(streak == 1 ? "day" : "days")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(theme.accent.swiftUI)
                }
                Spacer(minLength: 10)
                HStack(alignment: .bottom) {
                    if let streak {
                        Text(streak > 0 ? "Active \(streak) days in a row!" : "Start a streak today")
                            .font(.system(size: 9, design: .rounded))
                            .foregroundStyle(theme.ink.swiftUI.opacity(0.75))
                    }
                    Spacer(minLength: 4)
                    Image(systemName: "pawprint.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(theme.accent.swiftUI)
                }
            }
        }
    }

    // MARK: Middle row

    private var activityCard: some View {
        StatisticsCard(theme: theme) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    title("Token activity")
                    Spacer(minLength: 4)
                    Text("7 days")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(theme.ink.swiftUI.opacity(0.7))
                }
                subtitle("Daily token consumption")
                if let week {
                    TokenActivityChart(week: week, theme: theme)
                        .frame(height: 118)
                        .padding(.top, 10)
                } else {
                    placeholder("Counting…", height: 128)
                }
                HStack(spacing: 10) {
                    ForEach(TokenProvider.allCases, id: \.rawValue) { provider in
                        HStack(spacing: 4) {
                            Circle().fill(provider.color(theme)).frame(width: 6, height: 6)
                            Text(verbatim: provider.displayName)
                        }
                    }
                    Spacer(minLength: 4)
                    Text("Today so far")
                }
                .font(.system(size: 9, design: .rounded))
                .foregroundStyle(theme.ink.swiftUI.opacity(0.72))
                .padding(.top, 8)
            }
        }
    }

    private var providersCard: some View {
        StatisticsCard(theme: theme) {
            VStack(alignment: .leading, spacing: 0) {
                title("Providers")
                subtitle("Last 7 days · Token share")
                if let snapshot = cost.snapshot, snapshot.weekTotal.tokens > 0 {
                    let shares = ProviderShare.of(snapshot.week)
                    ShareBar(shares: shares, theme: theme)
                        .padding(.top, 9)
                    ForEach(Array(shares.enumerated()), id: \.offset) { index, share in
                        if index > 0 {
                            Rectangle().fill(theme.panelHighlight.swiftUI.opacity(0.45)).frame(height: 1)
                        }
                        providerRow(share, usage: snapshot.week[share.provider] ?? ProviderCostSummary())
                    }
                    Spacer(minLength: 0)
                    if settings.showEstimatedCost, snapshot.weekTotal.estimate.pricedTokens
                        + snapshot.weekTotal.estimate.unpricedTokens > 0 {
                        let estimate = snapshot.weekTotal.estimate
                        let coverage = Double(estimate.pricedTokens)
                            / Double(estimate.pricedTokens + estimate.unpricedTokens) * 100
                        Text("Cost coverage \(StoreFormat.percent(coverage.rounded()))")
                            .font(.system(size: 9, design: .rounded))
                            .foregroundStyle(theme.ink.swiftUI.opacity(0.6))
                            .help(CostEstimate.explanation)
                    }
                } else {
                    placeholder("Counting…", height: 60)
                }
            }
        }
    }

    private func providerRow(_ share: ProviderShare, usage: ProviderCostSummary) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                Circle().fill(share.provider.color(theme)).frame(width: 6, height: 6)
                Text(verbatim: share.provider.displayName)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                Spacer(minLength: 4)
                Text(verbatim: "\(share.percent)%")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
            .foregroundStyle(theme.ink.swiftUI)
            HStack {
                Text("\(TokenCount.compact(usage.tokens)) tokens")
                Spacer(minLength: 4)
                if settings.showEstimatedCost {
                    Text(verbatim: usage.estimate.label)
                        .help(CostEstimate.explanation)
                }
            }
            .font(.system(size: 9, design: .rounded))
            .foregroundStyle(theme.ink.swiftUI.opacity(0.7))
        }
        .padding(.vertical, 8)
    }

    // MARK: Bottom

    private var journeyCard: some View {
        StatisticsCard(theme: theme) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    title("Your coding journey")
                    Spacer(minLength: 4)
                    Label {
                        Text(verbatim: "365D")
                    } icon: {
                        Image(systemName: "calendar")
                    }
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(theme.ink.swiftUI.opacity(0.7))
                }
                if let year = history.year {
                    subtitle("\(TokenCount.compact(year.total)) tokens · Last 365 days")
                    ContributionGrassView(year: year, theme: theme)
                        .frame(height: 104)
                        .padding(.top, 10)
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(theme.accent.swiftUI)
                        Text("Keep the streak alive")
                        Spacer(minLength: 4)
                        Text("Less")
                        ForEach(0..<4, id: \.self) { level in
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(theme.levels[level].swiftUI)
                                .frame(width: 8, height: 8)
                        }
                        Text("More")
                    }
                    .font(.system(size: 9, design: .rounded))
                    .foregroundStyle(theme.ink.swiftUI.opacity(0.72))
                    .padding(.top, 8)
                } else {
                    placeholder("Building the graph…", height: 140)
                }
            }
        }
    }

    // MARK: Pieces

    private func caption(_ text: LocalizedStringResource) -> some View {
        Text(text)
            .textCase(.uppercase)
            .font(.system(size: 9, weight: .semibold, design: .rounded))
            .foregroundStyle(theme.ink.swiftUI.opacity(0.72))
            .padding(.bottom, 6)
    }

    private func figure(_ value: String?) -> some View {
        LoadingValue(text: value)
            .font(.system(size: 20, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(theme.ink.swiftUI)
    }

    private func estimate(_ label: String?) -> some View {
        Group {
            if let label {
                Text("\(label) estimated")
            } else {
                LoadingValue(text: nil)
            }
        }
        .font(.system(size: 9, design: .rounded))
        .foregroundStyle(theme.accent.swiftUI.opacity(0.85))
        .help(CostEstimate.explanation)
        .padding(.top, 3)
    }

    private func title(_ text: LocalizedStringResource) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(theme.ink.swiftUI)
    }

    private func subtitle(_ text: LocalizedStringResource) -> some View {
        Text(text)
            .font(.system(size: 9, design: .rounded))
            .foregroundStyle(theme.ink.swiftUI.opacity(0.66))
            .padding(.top, 2)
    }

    private func placeholder(_ label: LocalizedStringResource, height: CGFloat) -> some View {
        Text(label)
            .font(.system(size: 10, design: .rounded))
            .foregroundStyle(theme.ink.swiftUI.opacity(0.7))
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: height)
    }
}

private struct ContentBottom: PreferenceKey {
    static let defaultValue = 0.0
    static func reduce(value: inout Double, nextValue: () -> Double) { value = max(value, nextValue()) }
}

/// One dashboard tile: a step darker than the panel, like Home's cards. `tint` washes it with the accent.
private struct StatisticsCard<Content: View>: View {
    let theme: RoomTheme
    var tint = false
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(ZStack {
                RoundedRectangle(cornerRadius: 8).fill(theme.surface.swiftUI)
                if tint { RoundedRectangle(cornerRadius: 8).fill(theme.accent.swiftUI.opacity(0.08)) }
            })
    }
}
