import SwiftUI

/// "에이전트 사용 한도": the selected provider's windows under a title with name-only tabs; charts live in Statistics.
struct UsageDashboardView: View {
    let theme: RoomTheme
    let display: HomeDisplaySettings
    @ObservedObject private var limits = UsageLimitsModel.shared
    @State private var selectedProviderID: String?
    @Namespace private var providerSelection
    @State private var connectionError: LocalizedStringResource = ""
    @State private var showsConnectionError = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let cards = UsagePresentation.cards(sources: limits.sources, settings: display, now: context.date)
            let selected = cards.first(where: { $0.id == selectedProviderID }) ?? cards.first
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    HomeLedgerTitle(text: "Agent usage limits")
                    Spacer(minLength: 0)
                    if !cards.isEmpty {
                        HStack(spacing: 2) {
                            ForEach(visibleCards(cards, selected: selected)) { card in
                                chip(card, selected: card.id == selected?.id)
                            }
                        }
                    }
                    if cards.count > 3 {
                        Menu {
                            ForEach(cards) { card in
                                Button(card.name) {
                                    withAnimation(.easeInOut(duration: 0.22)) { selectedProviderID = card.id }
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(theme.ink.swiftUI)
                        }
                        .menuStyle(.borderlessButton)
                        .help("Other agents")
                    }
                }
                .frame(height: 22)

                if let selected {
                    if selected.details.isEmpty {
                        emptyDetails(selected)
                    } else {
                        let rows = VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(selected.details.enumerated()), id: \.offset) { _, detail in
                                detailRow(detail)
                            }
                        }
                        // Two windows fit; a provider with more scrolls inside the same space.
                        Group {
                            if selected.details.count > 2 {
                                ScrollView(.vertical) { rows }.scrollIndicators(.hidden)
                            } else {
                                rows
                            }
                        }
                        .frame(height: 54, alignment: .top)
                        .id(selected.id)
                        .transition(.opacity)
                    }
                } else {
                    Text("No agents to show")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(theme.ink.swiftUI.opacity(0.75))
                        .frame(height: 54)
                }
            }
            .animation(.easeInOut(duration: 0.22), value: selectedProviderID)
        }
        .task {
            while !Task.isCancelled {
                await limits.refresh()
                try? await Task.sleep(for: .seconds(30))
            }
        }
        .alert("Could not connect Claude limits", isPresented: $showsConnectionError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(connectionError)
        }
    }

    private func chip(_ card: UsageCard, selected: Bool) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.22)) { selectedProviderID = card.id }
        } label: {
            Text(card.name)
                .font(.system(size: 10, weight: selected ? .bold : .medium, design: .rounded))
                .foregroundStyle(theme.ink.swiftUI.opacity(selected ? 1 : 0.75))
                .lineLimit(1)
                .frame(minWidth: 56, minHeight: 22)
                .background {
                    if selected {
                        Capsule().fill(theme.surface.swiftUI)
                            .matchedGeometryEffect(id: "activeProvider", in: providerSelection)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    private func visibleCards(_ cards: [UsageCard], selected: UsageCard?) -> [UsageCard] {
        guard cards.count > 3 else { return cards }
        var visible = Array(cards.prefix(2))
        if let selected, !visible.contains(where: { $0.id == selected.id }) {
            visible.append(selected)
        } else {
            visible.append(cards[2])
        }
        return visible
    }

    private func emptyDetails(_ card: UsageCard) -> some View {
        HStack(spacing: 8) {
            Text(card.summary.text)
                .foregroundStyle(theme.ink.swiftUI.opacity(0.75))
            if card.id == "claude" && card.state == .needsConnection {
                connectButton
            }
            Spacer(minLength: 0)
        }
        .font(.system(size: 11, weight: .medium, design: .rounded))
        .frame(height: 54)
    }

    private var connectButton: some View {
        Button("Connect", action: connectClaude)
            .buttonStyle(.plain)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(theme.ink.swiftUI)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(theme.panelEdge.swiftUI, in: RoundedRectangle(cornerRadius: 4))
            .help("Connect Claude Code limits")
    }

    /// "5시간 ··· 7%  1시간 49분 뒤 리셋" over a full-width bar.
    private func detailRow(_ detail: UsageDetail) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(detail.kind.title)
                Spacer(minLength: 0)
                if let value = detail.value {
                    Text(value).font(.system(size: 12, weight: .bold, design: .rounded))
                }
                if let note = detail.noteText {
                    note.opacity(0.7)
                }
            }
            if let fraction = detail.fraction {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(theme.levels[0].swiftUI)
                        Capsule().fill(color(detail))
                            .frame(width: max(geometry.size.width * fraction, fraction > 0 ? 4 : 0))
                    }
                }
                .frame(height: 4)
                .accessibilityHidden(true)
            }
        }
        .font(.system(size: 11, weight: .medium, design: .rounded))
        .foregroundStyle(theme.ink.swiftUI)
        .monospacedDigit()
        .lineLimit(1)
        .accessibilityElement(children: .combine)
    }

    private func color(_ detail: UsageDetail) -> Color {
        switch detail.tier {
        case .critical: return Color(red: 0.96, green: 0.43, blue: 0.38)
        case .warning: return Color(red: 0.96, green: 0.75, blue: 0.39)
        case .normal: return theme.levels[2].swiftUI
        }
    }

    private func connectClaude() {
        guard let script = Bundle.main.url(forResource: "tokencats-statusline", withExtension: "py") else {
            showConnectionError("The app has no Claude status line script.")
            return
        }
        do {
            try StatusLineIntegration.claude.install(bundledScript: script)
            Task { await limits.refresh() }
        } catch HookIntegration.Failure.agentNotInstalled {
            showConnectionError("Could not find the Claude Code settings folder.")
        } catch HookIntegration.Failure.invalidConfig {
            showConnectionError("Could not read the JSON in the Claude settings file.")
        } catch StatusLineIntegration.Failure.pythonUnavailable {
            showConnectionError("Xcode Command Line Tools are required. Run xcode-select --install and try again.")
        } catch {
            showConnectionError("\(error.localizedDescription)")
        }
    }

    private func showConnectionError(_ message: LocalizedStringResource) {
        connectionError = message
        showsConnectionError = true
    }
}
