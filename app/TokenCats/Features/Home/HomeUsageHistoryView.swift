import SwiftUI

struct HomeUsageHistoryView: View {
    let theme: RoomTheme
    let display: HomeDisplaySettings
    @ObservedObject private var churu = ChuruModel.shared
    @ObservedObject private var history = HomeUsageHistoryModel.shared
    @ObservedObject private var cost = CostUsageModel.shared

    private var week: WeekUsage? {
        if let daily = cost.snapshot?.dailyTokens {
            return WeekUsage.make(dailyTokens: daily, today: Date(), calendar: .current)
        }
        return history.week
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            if display.showContributionGraph {
                if let year = history.year {
                    VStack(alignment: .leading, spacing: 9) {
                        ContributionGrassView(year: year, theme: theme)
                            .frame(height: 128)
                        HStack(spacing: 12) {
                            yearMetric("365-day total", value: "\(TokenCount.compact(year.total)) tokens")
                            yearMetric("Average per active day", value: "\(TokenCount.compact(year.averagePerActiveDay))")
                            yearMetric("Usage streak", value: "\(year.currentStreak) days")
                        }
                    }
                } else {
                    placeholder("Building the graph…", height: 168)
                }
            }
            if display.showWeeklyTokens || display.showWeeklyChart {
                GeometryReader { geometry in
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(spacing: 8) {
                                Text("Last 7 days")
                                    .foregroundStyle(theme.ink.swiftUI.opacity(0.76))
                                Text(week.map { "\(TokenCount.compact($0.total)) tokens" } ?? "Counting…" as LocalizedStringResource)
                                    .foregroundStyle(theme.ink.swiftUI)
                            }
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            if display.showEstimatedCost {
                                LoadingValue(text: cost.snapshot?.weekTotal.estimate.label)
                                    .font(.system(size: 10, design: .rounded))
                                    .foregroundStyle(theme.ink.swiftUI.opacity(0.75))
                                    .help(CostEstimate.explanation)
                            }
                            if display.showWeeklyChart, let week {
                                WeeklyTokenChart(week: week, theme: theme)
                                    .frame(height: 64)
                            }
                        }
                        .frame(width: geometry.size.width * 0.68, alignment: .leading)
                        providerBreakdown
                            .frame(width: geometry.size.width * 0.29, alignment: .leading)
                    }
                }
                .frame(height: display.showWeeklyChart ? 110 : 88)
                if display.showEstimatedCost, let estimate = cost.snapshot?.weekTotal.estimate,
                   estimate.pricedTokens + estimate.unpricedTokens > 0 {
                    let coverage = Double(estimate.pricedTokens)
                        / Double(estimate.pricedTokens + estimate.unpricedTokens) * 100
                    Text("Cost coverage \(StoreFormat.percent(coverage.rounded()))")
                        .font(.system(size: 9, design: .rounded))
                        .foregroundStyle(theme.ink.swiftUI.opacity(0.65))
                        .help(CostEstimate.explanation)
                }
            }
        }
        .task(id: churu.snapshot?.todayTokens) {
            history.refresh(day: churu.snapshot?.day ?? ChuruLedger.dayKey(Date(), .current),
                            todayTokens: churu.snapshot?.todayTokens ?? 0)
        }
    }

    private var providerBreakdown: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("7 days by provider")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(theme.ink.swiftUI.opacity(0.75))
            ForEach(TokenProvider.allCases, id: \.rawValue) { provider in
                let usage = cost.snapshot?.week[provider]
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(provider.rawValue.capitalized)
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                        Spacer(minLength: 2)
                        if let usage, let total = cost.snapshot?.weekTotal.tokens, total > 0 {
                            Text("\(Int((Double(usage.tokens) / Double(total) * 100).rounded()))%")
                                .font(.system(size: 9, design: .rounded))
                                .foregroundStyle(theme.ink.swiftUI.opacity(0.7))
                        }
                    }
                    HStack(spacing: 4) {
                        LoadingValue(text: usage.map { TokenCount.compact($0.tokens) })
                        Spacer(minLength: 1)
                        if display.showEstimatedCost {
                            LoadingValue(text: usage?.estimate.label)
                                .help(CostEstimate.explanation)
                        }
                    }
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(theme.ink.swiftUI.opacity(0.8))
                }
                .foregroundStyle(theme.ink.swiftUI)
                if provider != TokenProvider.allCases.last {
                    Rectangle().fill(theme.panelHighlight.swiftUI.opacity(0.45)).frame(height: 1)
                }
            }
        }
    }

    private func yearMetric(_ title: LocalizedStringResource, value: LocalizedStringResource) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(theme.ink.swiftUI.opacity(0.66))
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(theme.ink.swiftUI)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func placeholder(_ label: LocalizedStringResource, height: CGFloat) -> some View {
        Text(label)
            .font(.system(size: 11, design: .rounded))
            .foregroundStyle(theme.ink.swiftUI.opacity(0.7))
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: height)
    }
}

private struct WeeklyTokenChart: View {
    let week: WeekUsage
    let theme: RoomTheme
    private let weekdays: [LocalizedStringResource] = ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .bottom, spacing: 7) {
                ForEach(Array(week.days.enumerated()), id: \.offset) { index, day in
                    let height = day.tokens > 0 && week.peak > 0
                        ? max(3.0, Double(day.tokens) / Double(week.peak) * 46.0) : 2.0
                    VStack(spacing: 4) {
                        ZStack(alignment: .bottom) {
                            Color.clear.frame(height: 46)
                            RoundedRectangle(cornerRadius: 2)
                                .fill((day.tokens == 0 ? theme.levels[0]
                                       : (index == 6 ? theme.levels[3] : theme.levels[2])).swiftUI)
                                .frame(width: 30, height: height)
                        }
                        Text(weekdays[day.weekday])
                            .font(.system(size: 9, weight: .medium, design: .rounded))
                            .foregroundStyle(theme.ink.swiftUI.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity)
                    .help("\(day.dayKey): \(TokenCount.compact(day.tokens)) tokens")
                }
            }
        }
    }
}

/// The same 53 × 7 activity grid, levels, month labels and paw stamp as the GitHub profile card.
private struct ContributionGrassView: View {
    let year: ContributionYear
    let theme: RoomTheme
    private let horizontalPitch = 11.0
    private let verticalPitch = 12.0
    private let tile = 10.0

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Last 365 days")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(theme.ink.swiftUI)
            Canvas { graphics, size in
                let left = max(0, (size.width - Double(ContributionYear.weeks) * horizontalPitch) / 2).rounded()
                for label in year.monthLabels {
                    let text = Text(label.name)
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundColor(theme.ink.swiftUI.opacity(0.75))
                    graphics.draw(graphics.resolve(text),
                                  at: CGPoint(x: left + Double(label.column) * horizontalPitch, y: 0), anchor: .topLeading)
                }
                for (column, days) in year.columns.enumerated() {
                    for (row, cell) in days.enumerated() {
                        guard let level = cell.level else { continue }
                        let x = left + Double(column) * horizontalPitch
                        let y = 17.0 + Double(row) * verticalPitch
                        let rect = CGRect(x: x, y: y, width: tile, height: tile)
                        graphics.fill(Path(roundedRect: rect, cornerRadius: 1.3),
                                      with: .color(theme.levels[min(max(level, 0), 3)].swiftUI))
                        if level == 3 {
                            let pixel = tile / 12
                            for (pawRow, line) in ContributionPaw.rows.enumerated() {
                                for (pawColumn, mark) in line.enumerated() where mark == "X" {
                                    graphics.fill(Path(CGRect(x: x + Double(pawColumn) * pixel,
                                                              y: y + Double(pawRow) * pixel,
                                                              width: pixel, height: pixel)),
                                                  with: .color(theme.stamp.swiftUI))
                                }
                            }
                        }
                    }
                }
            }
            .frame(height: 108)
            .accessibilityLabel("Agent activity graph for the last 365 days")
        }
    }
}
