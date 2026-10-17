import SwiftUI

extension TokenProvider {
    var displayName: String { rawValue.capitalized }

    /// Claude takes the theme's accent; Codex a quiet ink, so the two read apart on every background.
    /// `lit` is a lighter tone for a day still being counted.
    func color(_ theme: RoomTheme, lit: Bool = false) -> Color {
        switch self {
        case .claude: return (lit ? theme.accent.mixed(with: theme.ink, 0.45) : theme.accent).swiftUI
        case .codex: return theme.ink.swiftUI.opacity(lit ? 0.75 : 0.55)
        }
    }
}

/// One provider's slice of a total, as a whole percent.
struct ProviderShare: Equatable {
    let provider: TokenProvider
    let tokens: Int
    let percent: Int

    /// Every provider in a fixed order, so the bar and the rows do not swap places between refreshes.
    static func of(_ usage: [TokenProvider: ProviderCostSummary]) -> [ProviderShare] {
        let total = usage.values.reduce(0) { $0 + $1.tokens }
        return TokenProvider.allCases.map { provider in
            let tokens = usage[provider]?.tokens ?? 0
            return ProviderShare(provider: provider, tokens: tokens,
                                 percent: total > 0 ? Int((Double(tokens) / Double(total) * 100).rounded()) : 0)
        }
    }
}

/// A thin capsule split by provider share.
struct ShareBar: View {
    let shares: [ProviderShare]
    let theme: RoomTheme

    var body: some View {
        GeometryReader { geometry in
            let total = max(1, shares.reduce(0) { $0 + $1.tokens })
            let visible = shares.filter { $0.tokens > 0 }
            HStack(spacing: 2) {
                ForEach(visible, id: \.provider) { share in
                    Capsule()
                        .fill(share.provider.color(theme))
                        .frame(width: max(3, (geometry.size.width - Double(visible.count - 1) * 2)
                                         * Double(share.tokens) / Double(total)))
                }
            }
        }
        .frame(height: 5)
    }
}

/// The last seven days as bars stacked by provider over dashed guide lines; today, still counting, is lighter.
struct TokenActivityChart: View {
    let week: WeekUsage
    let theme: RoomTheme
    private let weekdays: [LocalizedStringResource] = ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    private let labelHeight = 16.0

    var body: some View {
        GeometryReader { geometry in
            let plot = geometry.size.height - labelHeight
            ZStack(alignment: .topLeading) {
                ForEach(0..<4, id: \.self) { line in
                    Path { path in
                        let y = (plot * Double(line) / 3).rounded() + 0.5
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                    }
                    .stroke(theme.panelHighlight.swiftUI.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                }
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(Array(week.days.enumerated()), id: \.offset) { index, day in
                        VStack(spacing: 4) {
                            bar(day, today: index == week.days.count - 1, plot: plot - 4)
                                .frame(height: plot - 4, alignment: .bottom)
                            Text(weekdays[day.weekday])
                                .font(.system(size: 9, weight: .medium, design: .rounded))
                                .foregroundStyle(theme.ink.swiftUI.opacity(0.8))
                                .frame(height: labelHeight - 4)
                        }
                        .frame(maxWidth: .infinity)
                        .help("\(day.dayKey): \(TokenCount.compact(day.tokens)) tokens")
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    @ViewBuilder
    private func bar(_ day: WeekUsageDay, today: Bool, plot: Double) -> some View {
        let height = day.tokens > 0 && week.peak > 0 ? max(3.0, Double(day.tokens) / Double(week.peak) * plot) : 2.0
        // Days known only as totals (before the first log scan) draw as one Claude-coloured block.
        let parts: [(TokenProvider, Int)] = day.providers.isEmpty
            ? [(.claude, day.tokens)]
            : TokenProvider.allCases.map { ($0, day.providers[$0] ?? 0) }.filter { $0.1 > 0 }
        VStack(spacing: 1) {
            if day.tokens == 0 {
                RoundedRectangle(cornerRadius: 2).fill(theme.levels[0].swiftUI).frame(height: 2)
            } else {
                // Top to bottom in case order: Claude above, Codex at the base.
                ForEach(parts, id: \.0) { provider, tokens in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(provider.color(theme, lit: today))
                        .frame(height: max(2, height * Double(tokens) / Double(day.tokens) - 1))
                }
            }
        }
        .frame(maxWidth: 30)
    }
}

/// The same 53 × 7 activity grid, levels, month labels and paw stamp as the GitHub profile card.
struct ContributionGrassView: View {
    let year: ContributionYear
    let theme: RoomTheme
    private let horizontalPitch = 11.0
    private let verticalPitch = 12.0
    private let tile = 10.0

    var body: some View {
        Canvas { graphics, size in
                // 53 columns at the full pitch need 583pt; a narrower panel shrinks the pitch rather than
                // losing the newest weeks off the right edge.
                let pitch = min(horizontalPitch, (size.width / Double(ContributionYear.weeks)).rounded(.down))
                let tile = min(self.tile, pitch - 1)
                let left = max(0, (size.width - Double(ContributionYear.weeks) * pitch) / 2).rounded()
                for label in year.monthLabels {
                    let text = Text(label.name)
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundColor(theme.ink.swiftUI.opacity(0.75))
                    graphics.draw(graphics.resolve(text),
                                  at: CGPoint(x: left + Double(label.column) * pitch, y: 0), anchor: .topLeading)
                }
                for (column, days) in year.columns.enumerated() {
                    for (row, cell) in days.enumerated() {
                        guard let level = cell.level else { continue }
                        let x = left + Double(column) * pitch
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
        .accessibilityLabel("Agent activity graph for the last 365 days")
    }
}
