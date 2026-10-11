import KeyboardShortcuts
import SwiftUI

// The six first-run pages. Each page takes its state from outside, so the
// design snapshots (DebugSnapshots, NC_SNAPSHOT_ONBOARDING) and the real flow draw the same views.

/// The window size every page is laid out for.
let onboardingWindowSize = CGSize(width: 480, height: 640)

/// Top bar: progress dots, back, and skip.
struct OnboardingHeader: View {
    let theme: RoomTheme
    let step: Int
    var onBack: (() -> Void)?
    var onSkip: (() -> Void)?

    var body: some View {
        HStack {
            Group {
                if let onBack {
                    Button(action: onBack) { Label("Back", systemImage: "chevron.left") }
                } else {
                    Color.clear
                }
            }
            .frame(width: 90, alignment: .leading)
            Spacer()
            HStack(spacing: 6) {
                ForEach(1...6, id: \.self) { index in
                    Capsule()
                        .fill(index == step ? theme.accent.swiftUI : theme.ink.swiftUI.opacity(index < step ? 0.55 : 0.2))
                        .frame(width: index == step ? 18 : 6, height: 6)
                }
            }
            Spacer()
            Group {
                if let onSkip { Button("Skip", action: onSkip) } else { Color.clear }
            }
            .frame(width: 90, alignment: .trailing)
        }
        .buttonStyle(.plain)
        .font(.system(size: 12, weight: .bold, design: .rounded))
        .foregroundStyle(theme.ink.swiftUI.opacity(0.7))
        .frame(height: 20)
        .padding(.horizontal, 24)
        .padding(.top, 20)
    }
}

/// Title with the brand paw, and one line under it, the same on every page.
struct OnboardingTitle: View {
    /// Gap under the header: every page puts its title at the same height, so moving between pages does not jump.
    static let top: CGFloat = 36

    let theme: RoomTheme
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Text(title).font(.system(size: 24, weight: .heavy, design: .rounded))
                PixelPaw(color: theme.accent.swiftUI, size: 20)
            }
            Text(subtitle)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(theme.ink.swiftUI.opacity(0.75))
                .lineSpacing(3)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 36)
    }
}

/// A darker rounded box on the page.
struct OnboardingCard<Content: View>: View {
    let theme: RoomTheme
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 14).fill(theme.surface.swiftUI))
    }
}

/// The page's buttons, pinned to the bottom.
struct OnboardingFooter: View {
    let theme: RoomTheme
    let primary: LocalizedStringKey
    var secondary: LocalizedStringKey?
    var onPrimary: () -> Void = {}
    var onSecondary: () -> Void = {}

    var body: some View {
        HStack(spacing: 10) {
            if let secondary {
                Button(secondary, action: onSecondary).buttonStyle(OnboardingSecondaryButtonStyle(theme: theme))
            }
            Button(primary, action: onPrimary)
                .buttonStyle(OnboardingPrimaryButtonStyle(theme: theme))
                .keyboardShortcut(.defaultAction)
        }
        .padding(.bottom, 32)
    }
}

// MARK: - 1 Welcome

struct OnboardingWelcomeStep: View {
    var onNext: () -> Void = {}
    var onSkip: () -> Void = {}
    @ObservedObject private var language = AppLanguage.shared

    var body: some View {
        OnboardingPage { theme in
            VStack(spacing: 0) {
                OnboardingHeader(theme: theme, step: 1, onSkip: onSkip)
                    .padding(.bottom, OnboardingTitle.top)
                RoomPreview(theme: theme)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(theme.panelEdge.swiftUI, lineWidth: 2))
                    .padding(.horizontal, 32)
                    .padding(.bottom, 24)
                HStack(spacing: 10) {
                    Text(verbatim: "TokenCats").font(.system(size: 30, weight: .heavy, design: .rounded))
                    PixelPaw(color: theme.accent.swiftUI, size: 24)
                }
                .padding(.bottom, 8)
                Text("Tokens you spend on coding agents turn into churu,\nand churu adopts cats that live in your notch.")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.ink.swiftUI.opacity(0.75))
                    .lineSpacing(3)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)
                Spacer(minLength: 16)
                OnboardingCard(theme: theme) {
                    Label("Reads only the Claude Code and Codex records on this Mac. The only thing that leaves it is your GitHub card, and only if you connect it.",
                          systemImage: "lock.fill")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(theme.ink.swiftUI.opacity(0.85))
                    HStack {
                        Text("Language").font(.system(size: 12, weight: .bold, design: .rounded))
                        Spacer()
                        Picker("Language", selection: $language.selection) {
                            Text("Follow system").tag(AppLanguage.systemSelection)
                            ForEach(language.available) { Text(verbatim: $0.name).tag($0.code) }
                        }
                        .labelsHidden()
                        .fixedSize()
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
                OnboardingFooter(theme: theme, primary: "Get started", onPrimary: onNext)
            }
        }
    }
}

// MARK: - 2 Agents

/// What the agents page shows for one agent.
enum OnboardingAgentState {
    case connected, notConnected, notInstalled, needsPython
}

struct OnboardingAgentsStep: View {
    let claude: OnboardingAgentState
    let codex: OnboardingAgentState
    var onBack: () -> Void = {}
    var onNext: () -> Void = {}

    var body: some View {
        OnboardingPage { theme in
            VStack(spacing: 0) {
                OnboardingHeader(theme: theme, step: 2, onBack: onBack, onSkip: onNext)
                OnboardingTitle(theme: theme, title: "Connect your agents",
                                subtitle: "Connected agents show sessions waiting for you\nin the closed notch.")
                    .padding(.top, OnboardingTitle.top).padding(.bottom, 20)
                VStack(spacing: 10) {
                    card(theme, name: "Claude Code", color: AgentProvider.claude.badgeColor, state: claude)
                    card(theme, name: "Codex", color: AgentProvider.codex.badgeColor, state: codex)
                }
                .padding(.horizontal, 32)
                Text("Tokens and churu are counted even without connecting.")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.ink.swiftUI.opacity(0.6))
                    .padding(.top, 14)
                Spacer()
                OnboardingFooter(theme: theme, primary: "Next", onPrimary: onNext)
            }
        }
    }

    private func card(_ theme: RoomTheme, name: String, color: Color, state: OnboardingAgentState) -> some View {
        OnboardingCard(theme: theme) {
            HStack(spacing: 8) {
                Circle().fill(color).frame(width: 10, height: 10)
                Text(verbatim: name).font(.system(size: 15, weight: .heavy, design: .rounded))
                Spacer()
                switch state {
                case .connected:
                    Label("Connected", systemImage: "checkmark.circle.fill").foregroundStyle(theme.accent.swiftUI)
                case .notConnected:
                    Button("Connect") {}.buttonStyle(OnboardingPrimaryButtonStyle(theme: theme))
                case .notInstalled:
                    Text("Not installed").foregroundStyle(theme.ink.swiftUI.opacity(0.5))
                case .needsPython:
                    Label("Needs a setup", systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                }
            }
            .font(.system(size: 12, weight: .bold, design: .rounded))
            switch state {
            case .connected:
                EmptyView()
            case .notConnected where name == "Codex":
                note(theme, "After connecting, approve the hook with /hooks in Codex.")
            case .notConnected:
                EmptyView()
            case .notInstalled:
                note(theme, "It shows up here by itself once installed.")
            case .needsPython:
                note(theme, "Connecting needs the Xcode Command Line Tools. Run this in Terminal, then check again.")
                HStack {
                    Text(verbatim: "xcode-select --install")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 6).fill(theme.panel.swiftUI))
                    Button("Copy") {}.buttonStyle(OnboardingSecondaryButtonStyle(theme: theme, onCard: true))
                    Spacer()
                    Button("Check again") {}.buttonStyle(OnboardingSecondaryButtonStyle(theme: theme, onCard: true))
                }
            }
        }
        .opacity(state == .notInstalled ? 0.6 : 1)
    }

    private func note(_ theme: RoomTheme, _ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(theme.ink.swiftUI.opacity(0.7))
    }
}

// MARK: - 3 Claude limits

struct OnboardingLimitsStep: View {
    var onBack: () -> Void = {}
    var onNext: () -> Void = {}

    var body: some View {
        OnboardingPage { theme in
            VStack(spacing: 0) {
                OnboardingHeader(theme: theme, step: 3, onBack: onBack, onSkip: onNext)
                OnboardingTitle(theme: theme, title: "See your Claude limits",
                                subtitle: "Shows your 5-hour and weekly limits in the notch.")
                    .padding(.top, OnboardingTitle.top).padding(.bottom, 20)
                VStack(spacing: 12) {
                    OnboardingCard(theme: theme) {
                        bar(theme, "5-hour", 0.42)
                        bar(theme, "Weekly", 0.18)
                    }
                    OnboardingCard(theme: theme) {
                        Text("What changes").font(.system(size: 13, weight: .heavy, design: .rounded))
                        bullet(theme, "TokenCats wraps your Claude Code status line once.")
                        bullet(theme, "Your current status line keeps showing as it is.")
                        bullet(theme, "The original setting is backed up next to settings.json.")
                        bullet(theme, "Turn it off in Settings › Agents to put everything back.")
                    }
                }
                .padding(.horizontal, 32)
                Spacer()
                OnboardingFooter(theme: theme, primary: "Agree and turn on", secondary: "Later",
                                 onPrimary: onNext, onSecondary: onNext)
            }
        }
    }

    private func bar(_ theme: RoomTheme, _ label: LocalizedStringKey, _ value: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                Spacer()
                Text(value, format: .percent)
            }
            .font(.system(size: 12, weight: .bold, design: .rounded))
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(theme.panel.swiftUI)
                    Capsule().fill(theme.accent.swiftUI).frame(width: geometry.size.width * value)
                }
            }
            .frame(height: 8)
        }
    }

    private func bullet(_ theme: RoomTheme, _ text: LocalizedStringKey) -> some View {
        Label { Text(text) } icon: { Image(systemName: "checkmark").foregroundStyle(theme.accent.swiftUI) }
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(theme.ink.swiftUI.opacity(0.85))
    }
}

// MARK: - 4 GitHub card

/// Where the GitHub page is in connecting.
enum OnboardingGitHubPhase {
    case start, code(String), needsAccess(repoCreated: Bool), ready, done
}

struct OnboardingGitHubStep: View {
    let phase: OnboardingGitHubPhase
    let login: String
    /// The card as it will be uploaded, shown live through WebKit so its cats move.
    var cardSVG: String?
    /// A still of the card (design snapshots draw off screen, where a web view stays blank).
    var card: NSImage?
    var onBack: () -> Void = {}
    var onNext: () -> Void = {}

    var body: some View {
        OnboardingPage { theme in
            VStack(spacing: 0) {
                OnboardingHeader(theme: theme, step: 4, onBack: onBack, onSkip: onNext)
                OnboardingTitle(theme: theme, title: "Put your cats on GitHub",
                                subtitle: "Your cat room goes on top of your profile README\nand keeps itself up to date.")
                    .padding(.top, OnboardingTitle.top).padding(.bottom, 20)
                preview(theme)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 14)
                content(theme)
                    .padding(.horizontal, 32)
                Spacer()
                footer(theme)
            }
        }
    }

    @ViewBuilder private func preview(_ theme: RoomTheme) -> some View {
        Group {
            if let cardSVG {
                ProfileCardWebView(svg: cardSVG).aspectRatio(840 / 504, contentMode: .fit)
            } else if let card {
                Image(nsImage: card).resizable().aspectRatio(contentMode: .fit)
            } else {
                RoomPreview(theme: theme)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(alignment: .topLeading) {
            if case .done = phase {
                Label("On your profile", systemImage: "checkmark.seal.fill")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(theme.surface.swiftUI)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Capsule().fill(theme.accent.swiftUI))
                    .padding(8)
            }
        }
    }

    @ViewBuilder private func content(_ theme: RoomTheme) -> some View {
        switch phase {
        case .start:
            OnboardingCard(theme: theme) {
                Text("Shown to anyone").font(.system(size: 13, weight: .heavy, design: .rounded))
                check(theme, "The cat room", on: true, locked: true)
                check(theme, "Token numbers", on: true)
                check(theme, "Contribution graph and streak", on: true)
            }
        case let .code(code):
            OnboardingCard(theme: theme) {
                Text("Code to enter in the browser").font(.system(size: 13, weight: .heavy, design: .rounded))
                HStack {
                    Text(verbatim: code).font(.system(size: 26, weight: .heavy, design: .monospaced))
                    Spacer()
                    Button("Copy") {}.buttonStyle(OnboardingSecondaryButtonStyle(theme: theme, onCard: true))
                }
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("Opened github.com/login/device. Waiting for approval…")
                }
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(theme.ink.swiftUI.opacity(0.7))
            }
        case let .needsAccess(repoCreated):
            OnboardingCard(theme: theme) {
                Text("Two steps on GitHub").font(.system(size: 13, weight: .heavy, design: .rounded))
                task(theme, done: repoCreated, "Create your profile repo \(login)/\(login)")
                task(theme, done: false, "Install the TokenCats App and pick that repo")
                Text("Come back here when done; it checks again by itself.")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.ink.swiftUI.opacity(0.6))
            }
        case .ready:
            OnboardingCard(theme: theme) {
                Label("Connected as @\(login)", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                Text("Adds one image line between <!-- tokencats:start --> and end. Nothing else is changed.")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.ink.swiftUI.opacity(0.7))
            }
        case .done:
            OnboardingCard(theme: theme) {
                Text("Your card is on your profile").font(.system(size: 13, weight: .heavy, design: .rounded))
                Text(verbatim: "github.com/\(login)")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(theme.ink.swiftUI.opacity(0.7))
            }
        }
    }

    @ViewBuilder private func footer(_ theme: RoomTheme) -> some View {
        switch phase {
        case .start: OnboardingFooter(theme: theme, primary: "Connect with GitHub", secondary: "Later",
                                      onSecondary: onNext)
        case .code: OnboardingFooter(theme: theme, primary: "Open GitHub again", secondary: "Cancel")
        case .needsAccess: OnboardingFooter(theme: theme, primary: "Open GitHub", secondary: "Later",
                                            onSecondary: onNext)
        case .ready: OnboardingFooter(theme: theme, primary: "Add to my README", secondary: "Later",
                                      onSecondary: onNext)
        case .done: OnboardingFooter(theme: theme, primary: "Next", secondary: "View on GitHub", onPrimary: onNext)
        }
    }

    private func check(_ theme: RoomTheme, _ label: LocalizedStringKey, on: Bool, locked: Bool = false) -> some View {
        HStack {
            Image(systemName: on ? "checkmark.square.fill" : "square")
                .foregroundStyle(theme.accent.swiftUI.opacity(locked ? 0.5 : 1))
            Text(label)
            if locked { Text("Always").foregroundStyle(theme.ink.swiftUI.opacity(0.5)) }
        }
        .font(.system(size: 12, weight: .semibold, design: .rounded))
    }

    private func task(_ theme: RoomTheme, done: Bool, _ label: LocalizedStringKey) -> some View {
        HStack {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(done ? theme.accent.swiftUI : theme.ink.swiftUI.opacity(0.5))
            Text(label).strikethrough(done, color: theme.ink.swiftUI.opacity(0.5))
            Spacer()
            if !done { Button("Open") {}.buttonStyle(OnboardingSecondaryButtonStyle(theme: theme, onCard: true)) }
        }
        .font(.system(size: 12, weight: .semibold, design: .rounded))
    }
}

// MARK: - 5 Launch at login

struct OnboardingLoginItemStep: View {
    @State var isOn = true
    var onBack: () -> Void = {}
    var onNext: () -> Void = {}

    var body: some View {
        OnboardingPage { theme in
            VStack(spacing: 0) {
                OnboardingHeader(theme: theme, step: 5, onBack: onBack, onSkip: onNext)
                OnboardingTitle(theme: theme, title: "Start with your Mac?",
                                subtitle: "Tokens spent while TokenCats is closed\ndon't turn into churu.")
                    .padding(.top, OnboardingTitle.top).padding(.bottom, 20)
                Spacer()
                Image(systemName: "power.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(theme.accent.swiftUI)
                    .padding(.bottom, 20)
                OnboardingCard(theme: theme) {
                    Toggle(isOn: $isOn) {
                        Text("Launch at login").font(.system(size: 14, weight: .heavy, design: .rounded))
                    }
                    .toggleStyle(OnboardingSwitchStyle(theme: theme))
                }
                .padding(.horizontal, 32)
                Spacer()
                OnboardingFooter(theme: theme, primary: "Next", onPrimary: onNext)
            }
        }
    }
}

// MARK: - 6 Finish

/// One line of the finish page's summary.
struct OnboardingSummaryItem: Identifiable {
    let id = UUID()
    let label: LocalizedStringKey
    let done: Bool
}

struct OnboardingFinishStep: View {
    let summary: [OnboardingSummaryItem]
    let churu: Int
    let adoptionPrice: Int
    var onBack: () -> Void = {}
    var onFinish: () -> Void = {}

    var body: some View {
        OnboardingPage { theme in
            VStack(spacing: 0) {
                OnboardingHeader(theme: theme, step: 6, onBack: onBack)
                OnboardingTitle(theme: theme, title: "All set!", subtitle: "Your first cat is waiting in the notch.")
                    .padding(.top, OnboardingTitle.top).padding(.bottom, 20)
                VStack(spacing: 10) {
                    OnboardingCard(theme: theme) {
                        ForEach(summary) { item in
                            HStack {
                                Image(systemName: item.done ? "checkmark.circle.fill" : "minus.circle")
                                    .foregroundStyle(item.done ? theme.accent.swiftUI : theme.ink.swiftUI.opacity(0.4))
                                Text(item.label)
                                Spacer()
                                if !item.done {
                                    Text("Later in Settings").foregroundStyle(theme.ink.swiftUI.opacity(0.5))
                                }
                            }
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                        }
                    }
                    OnboardingCard(theme: theme) {
                        HStack(alignment: .firstTextBaseline) {
                            Image(systemName: "fish.fill").foregroundStyle(theme.accent.swiftUI)
                            Text(verbatim: TokenCount.compact(churu)).font(.system(size: 22, weight: .heavy, design: .rounded))
                            Text("churu").font(.system(size: 12, weight: .bold, design: .rounded))
                            Spacer()
                            Text("\(TokenCount.compact(adoptionPrice)) to your first adoption")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(theme.ink.swiftUI.opacity(0.7))
                        }
                        Capsule().fill(theme.panel.swiftUI).frame(height: 8)
                            .overlay(alignment: .leading) {
                                Capsule().fill(theme.accent.swiftUI)
                                    .frame(width: max(8, 352 * Double(churu) / Double(max(adoptionPrice, 1))))
                            }
                        Text("Churu counts the tokens you spend from now on.")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(theme.ink.swiftUI.opacity(0.6))
                    }
                    Text("Hover over the notch or press \(KeyboardShortcuts.getShortcut(for: .toggleNotchOpen)?.description ?? "⌘⇧I") to open it.")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(theme.ink.swiftUI.opacity(0.75))
                    .padding(.top, 6)
                }
                .padding(.horizontal, 32)
                Spacer()
                OnboardingFooter(theme: theme, primary: "Open the cat room", onPrimary: onFinish)
            }
        }
    }
}
