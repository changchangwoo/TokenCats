import SwiftUI

/// Today's three missions at the bottom of the ledger: one row per mission with Claim on the finished ones.
/// The chevron on the title row folds it to one line (the title and what is left); the choice sticks.
struct HomeMissionsSection: View {
    let theme: RoomTheme
    @ObservedObject private var churu = ChuruModel.shared
    @AppStorage(AppSettings.Key.missionsExpanded) private var expanded = AppSettings.Default.missionsExpanded

    var body: some View {
        // 15pt title + 3 × 20pt rows + 3 × 4pt gaps = 87pt, inside HomeLayout.missionsHeight (88).
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                HStack(spacing: 5) {
                    // The paw in the accent colour draws the eye down to the missions, as the fish does for churu.
                    Image(systemName: "pawprint.fill").foregroundStyle(theme.accent.swiftUI)
                        .font(.system(size: 11, weight: .medium))
                    HomeLedgerTitle(text: "Today's missions")
                }
                .opacity(contentOpacity)
                Spacer(minLength: 0)
                if !expanded, let missions = churu.snapshot?.missions {
                    foldedSummary(missions).opacity(contentOpacity)
                }
                Button {
                    withAnimation(.smooth(duration: 0.25)) { expanded.toggle() }
                } label: {
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .opacity(0.7)
                        .frame(width: 18, height: 18)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(expanded ? "Fold missions" : "Unfold missions")
            }
            if expanded {
                if let missions = churu.snapshot?.missions {
                    ForEach(missions, id: \.id) { mission in
                        row(mission).opacity(contentOpacity)
                    }
                } else {
                    LoadingDots().frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .clipped()
    }

    /// Everything claimed: the content goes quiet until tomorrow. The chevron stays, so the section can still
    /// be folded and unfolded.
    private var contentOpacity: Double { allClaimed ? 0.45 : 1 }

    private var allClaimed: Bool {
        guard let missions = churu.snapshot?.missions, !missions.isEmpty else { return false }
        return missions.allSatisfy { if case .claimed = $0.state { return true } else { return false } }
    }

    /// "1/3 · Pet a cat · Use 1M tokens" while missions remain; "3/3 · +190K ✓" once every reward is in.
    private func foldedSummary(_ missions: [MissionStatus]) -> some View {
        let claimed = missions.filter { if case .claimed = $0.state { return true } else { return false } }
        let remaining = missions.filter { if case .claimed = $0.state { return false } else { return true } }
        return HStack(spacing: 4) {
            Text(verbatim: "\(claimed.count)/\(missions.count)").monospacedDigit()
            if remaining.isEmpty {
                rewardLabel(churu.snapshot?.todayBonus ?? 0)
                Image(systemName: "checkmark.circle.fill").foregroundStyle(theme.accent.swiftUI)
            } else {
                remaining.dropFirst().map { Text(Self.name(of: $0.id)) }
                    .reduce(Text(Self.name(of: remaining[0].id))) { $0 + Text(verbatim: " · ") + $1 }
                    .lineLimit(1)
                    .opacity(0.7)
            }
        }
        .font(.system(size: 10, weight: .medium, design: .rounded))
        .opacity(0.85)
    }

    private func row(_ mission: MissionStatus) -> some View {
        HStack(spacing: 8) {
            Text(Self.name(of: mission.id))
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .lineLimit(1)
            if let progress = Self.progressLabel(mission) {
                Text(verbatim: progress)
                    .font(.system(size: 10, design: .rounded))
                    .monospacedDigit()
                    .opacity(0.7)
            }
            // The streak multiplier belongs to the missions, not to token income: it sits on the check-in row.
            if mission.id == .checkIn, let snapshot = churu.snapshot, snapshot.streakDays > 0,
               snapshot.missionMultiplier > 1 {
                HStack(spacing: 3) {
                    Image(systemName: "flame").foregroundStyle(theme.accent.swiftUI)
                    Text("\(snapshot.streakDays) day streak")
                    Text(verbatim: "· " + Self.multiplierLabel(snapshot.missionMultiplier)).monospacedDigit()
                }
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .opacity(0.85)
                .help("Streak bonus on today's mission rewards")
            }
            Spacer(minLength: 0)
            switch mission.state {
            case .inProgress:
                rewardLabel(mission.reward).opacity(0.6)
            case .claimable:
                Button {
                    Task { await churu.claim(mission.id) }
                } label: {
                    HStack(spacing: 4) {
                        rewardLabel(mission.reward)
                        Text("Claim")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(theme.accent.swiftUI)
                    }
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    // An outline, not a fill: the adoption button above stays the loudest thing on Home.
                    .overlay(Capsule().strokeBorder(theme.accent.swiftUI.opacity(0.55), lineWidth: 1))
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(churu.claiming != nil)
                .accessibilityLabel("Claim")
            case .claimed(let reward):
                HStack(spacing: 4) {
                    rewardLabel(reward)
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(theme.accent.swiftUI)
                }
                .help("Claimed")
            }
        }
        .frame(height: 20)
        .opacity(mission.state == .inProgress ? 0.75 : 1)
    }

    private func rewardLabel(_ reward: Int) -> some View {
        // verbatim: an interpolated key would reach the string catalog as "+%@" and fail check-strings.
        Text(verbatim: "+" + TokenCount.compact(reward))
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .monospacedDigit()
    }

    static func name(of id: MissionID) -> LocalizedStringKey {
        switch id {
        case .checkIn: return "Check in"
        case .pet: return "Pet a cat"
        case .tokens1M: return "Use 1M tokens"
        }
    }

    /// "0/1" for petting, "0.6M / 1M" for tokens; nothing for check-in, which the button itself completes.
    /// Numbers only, so nothing here is localized.
    static func progressLabel(_ mission: MissionStatus) -> String? {
        guard mission.id != .checkIn else { return nil }
        let done = min(mission.progress, mission.target)
        return mission.target >= 1_000
            ? "\(TokenCount.compact(done)) / \(TokenCount.price(mission.target))"
            : "\(done)/\(mission.target)"
    }

    static func multiplierLabel(_ multiplier: Double) -> String {
        "×" + String(format: "%.1f", multiplier)
    }
}
