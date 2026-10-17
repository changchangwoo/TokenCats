import SwiftUI

/// "에이전트 사용 한도": the selected provider's windows under a title with name-only tabs; charts live in Statistics.
struct UsageDashboardView: View {
    let theme: RoomTheme
    let display: HomeDisplaySettings
    @ObservedObject private var limits = UsageLimitsModel.shared
    @ObservedObject private var agents = AgentHub.shared
    @Namespace private var providerSelection
    @State private var connectionError: LocalizedStringResource = ""
    @State private var showsConnectionError = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let cards = UsagePresentation.cards(sources: limits.sources, settings: display, now: context.date)
            let selected = cards.first(where: { $0.id == limits.selectedProviderID }) ?? cards.first
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
                                    withAnimation(.easeInOut(duration: 0.22)) { limits.selectedProviderID = card.id }
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
                        // The Claude window holds 5-hour, weekly, and Fable; other providers keep their two rows.
                        Group {
                            if selected.details.count > 3 {
                                ScrollView(.vertical) { rows }.scrollIndicators(.visible)
                            } else {
                                rows
                            }
                        }
                        .frame(height: detailHeight, alignment: .top)
                        .id(selected.id)
                        .transition(.opacity)
                    }
                } else {
                    Text("No agents to show")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(theme.ink.swiftUI.opacity(0.75))
                        .frame(height: detailHeight)
                }
                if let selected { statusRow(for: selected.id).frame(height: 24) }
            }
            .animation(.easeInOut(duration: 0.22), value: limits.selectedProviderID)
        }
        .task {
            while !Task.isCancelled {
                agents.refreshClaudeStatusIfNeeded()
                agents.refreshOpenAIStatusIfNeeded()
                await limits.refresh()
                await limits.refreshFableIfNeeded()
                try? await Task.sleep(for: .seconds(30))
            }
        }
        .alert("Could not connect Claude limits", isPresented: $showsConnectionError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(connectionError)
        }
    }

    private var detailHeight: CGFloat { CGFloat(limits.visibleLimitRows(for: display)) * 27 }

    private func statusRow(for providerID: String) -> some View {
        HStack(spacing: 6) {
            Text(statusTitle(for: providerID))
                .font(.system(size: 10, weight: .semibold, design: .rounded))
            Spacer(minLength: 4)
            Circle().fill(statusColor(for: providerID)).frame(width: 6, height: 6)
            Text(statusText(for: providerID))
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(statusColor(for: providerID))
                .lineLimit(1)
            Button {
                NSWorkspace.shared.open(URL(string: providerID == "claude"
                                            ? "https://status.claude.com" : "https://status.openai.com")!)
            } label: {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 9, weight: .semibold))
            }
            .buttonStyle(.plain)
            .help(statusHelp(for: providerID))
        }
        .foregroundStyle(theme.ink.swiftUI)
        .padding(.top, 5)
    }

    private func statusTitle(for providerID: String) -> LocalizedStringResource {
        providerID == "claude" ? "Claude Code status" : "Codex Desktop status"
    }

    private func statusHelp(for providerID: String) -> LocalizedStringResource {
        providerID == "claude" ? "Open Claude status page"
        : "OpenAI publishes Codex Desktop status; CLI availability may differ"
    }

    private func statusText(for providerID: String) -> LocalizedStringResource {
        if providerID != "claude" {
            switch agents.openAIStatus {
            case .incident: return "Service issue reported"
            case .operational: return "Operational"
            case .unavailable: return "Status unavailable"
            case nil: return "Checking status…"
            }
        }
        if agents.claudeRequestFailed {
            if case .incident = agents.serviceStatus { return "Request failed · Service issue reported" }
            return "Recent request failed"
        }
        switch agents.serviceStatus {
        case .incident: return "Service issue reported"
        case .operational: return "Operational"
        case .unavailable: return "Status unavailable"
        case nil: return "Checking status…"
        }
    }

    private func statusColor(for providerID: String) -> Color {
        if providerID != "claude" {
            switch agents.openAIStatus {
            case .incident: return Color(red: 0.96, green: 0.43, blue: 0.38)
            case .operational: return Color(red: 0.42, green: 0.83, blue: 0.61)
            case .unavailable, nil: return theme.ink.swiftUI.opacity(0.65)
            }
        }
        if agents.claudeRequestFailed { return Color(red: 0.96, green: 0.43, blue: 0.38) }
        switch agents.serviceStatus {
        case .incident: return Color(red: 0.96, green: 0.43, blue: 0.38)
        case .operational: return Color(red: 0.42, green: 0.83, blue: 0.61)
        case .unavailable, nil: return theme.ink.swiftUI.opacity(0.65)
        }
    }

    private func chip(_ card: UsageCard, selected: Bool) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.22)) { limits.selectedProviderID = card.id }
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
