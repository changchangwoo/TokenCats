import KeyboardShortcuts
import SwiftUI

// The first-run pages. Each page takes its state and actions from outside (OnboardingFlowView in the app, fixed
// examples in the design snapshots), so both draw the same views.

/// The window size every page is laid out for.
let onboardingWindowSize = CGSize(width: 480, height: 640)

/// Where a page sits in the flow, for the progress dots (the limits page is left out without Claude Code).
struct OnboardingProgress {
    var step: Int
    var total = 6
}

/// Top bar: progress dots, back, and skip.
struct OnboardingHeader: View {
    let theme: RoomTheme
    let progress: OnboardingProgress
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
                ForEach(1...max(progress.total, 1), id: \.self) { index in
                    Capsule()
                        .fill(index == progress.step ? theme.accent.swiftUI
                              : theme.ink.swiftUI.opacity(index < progress.step ? 0.55 : 0.2))
                        .frame(width: index == progress.step ? 18 : 6, height: 6)
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

/// The result of the last action on a page, under its content.
struct OnboardingNotice: View {
    let theme: RoomTheme
    let notice: LocalizedStringResource?

    var body: some View {
        if let notice {
            Text(notice)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(theme.ink.swiftUI.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
                .padding(.top, 12)
        }
    }
}

/// The page's buttons, pinned to the bottom.
struct OnboardingFooter: View {
    let theme: RoomTheme
    let primary: LocalizedStringKey
    var secondary: LocalizedStringKey?
    var busy = false
    var onPrimary: () -> Void = {}
    var onSecondary: () -> Void = {}

    var body: some View {
        HStack(spacing: 10) {
            if let secondary {
                Button(secondary, action: onSecondary).buttonStyle(OnboardingSecondaryButtonStyle(theme: theme))
            }
            Button(action: onPrimary) {
                HStack(spacing: 6) {
                    if busy { ProgressView().controlSize(.small) }
                    Text(primary)
                }
            }
            .buttonStyle(OnboardingPrimaryButtonStyle(theme: theme))
            .keyboardShortcut(.defaultAction)
            .disabled(busy)
        }
        .padding(.bottom, 32)
    }
}

private func copyToClipboard(_ text: String) {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
}

// MARK: - 1 Welcome

struct OnboardingWelcomeStep: View {
    var progress = OnboardingProgress(step: 1)
    var onNext: () -> Void = {}
    var onSkip: () -> Void = {}
    @ObservedObject private var language = AppLanguage.shared

    var body: some View {
        OnboardingPage { theme in
            VStack(spacing: 0) {
                OnboardingHeader(theme: theme, progress: progress, onSkip: onSkip)
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

struct OnboardingAgentsStep: View {
    let claude: AgentSetupState
    let codex: AgentSetupState
    var progress = OnboardingProgress(step: 2)
    var notice: LocalizedStringResource?
    var onConnect: (AgentProvider) -> Void = { _ in }
    var onCheckAgain: () -> Void = {}
    var onBack: () -> Void = {}
    var onNext: () -> Void = {}

    private static let toolsCommand = "xcode-select --install"

    var body: some View {
        OnboardingPage { theme in
            VStack(spacing: 0) {
                OnboardingHeader(theme: theme, progress: progress, onBack: onBack, onSkip: onNext)
                OnboardingTitle(theme: theme, title: "Connect your agents",
                                subtitle: "Connected agents show sessions waiting for you\nin the closed notch.")
                    .padding(.top, OnboardingTitle.top).padding(.bottom, 20)
                VStack(spacing: 10) {
                    card(theme, provider: .claude, name: "Claude Code", state: claude)
                    card(theme, provider: .codex, name: "Codex", state: codex)
                }
                .padding(.horizontal, 32)
                Text("Tokens and churu are counted even without connecting.")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.ink.swiftUI.opacity(0.6))
                    .padding(.top, 14)
                OnboardingNotice(theme: theme, notice: notice)
                Spacer()
                OnboardingFooter(theme: theme, primary: "Next", onPrimary: onNext)
            }
        }
    }

    private func card(_ theme: RoomTheme, provider: AgentProvider, name: String, state: AgentSetupState) -> some View {
        OnboardingCard(theme: theme) {
            HStack(spacing: 8) {
                Circle().fill(provider.badgeColor).frame(width: 10, height: 10)
                Text(verbatim: name).font(.system(size: 15, weight: .heavy, design: .rounded))
                Spacer()
                switch state {
                case .connected:
                    Label("Connected", systemImage: "checkmark.circle.fill").foregroundStyle(theme.accent.swiftUI)
                case .notConnected:
                    Button("Connect") { onConnect(provider) }.buttonStyle(OnboardingPrimaryButtonStyle(theme: theme))
                case .notInstalled:
                    Text("Not installed").foregroundStyle(theme.ink.swiftUI.opacity(0.5))
                case .needsPython:
                    Label("Needs a setup", systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                }
            }
            .font(.system(size: 12, weight: .bold, design: .rounded))
            switch state {
            case .connected where provider == .codex, .notConnected where provider == .codex:
                note(theme, "After connecting, approve the hook with /hooks in Codex.")
            case .connected, .notConnected:
                EmptyView()
            case .notInstalled:
                note(theme, "It shows up here by itself once installed.")
            case .needsPython:
                note(theme, "Connecting needs the Xcode Command Line Tools. Run this in Terminal, then check again.")
                HStack {
                    Text(verbatim: Self.toolsCommand)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 6).fill(theme.panel.swiftUI))
                    Button("Copy") { copyToClipboard(Self.toolsCommand) }
                        .buttonStyle(OnboardingSecondaryButtonStyle(theme: theme, onCard: true))
                    Spacer()
                    Button("Check again", action: onCheckAgain)
                        .buttonStyle(OnboardingSecondaryButtonStyle(theme: theme, onCard: true))
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
    var isOn = false
    var progress = OnboardingProgress(step: 3)
    var notice: LocalizedStringResource?
    var onTurnOn: () -> Void = {}
    var onBack: () -> Void = {}
    var onNext: () -> Void = {}

    var body: some View {
        OnboardingPage { theme in
            VStack(spacing: 0) {
                OnboardingHeader(theme: theme, progress: progress, onBack: onBack, onSkip: onNext)
                OnboardingTitle(theme: theme, title: "See your Claude limits",
                                subtitle: "Shows your 5-hour and weekly limits in the notch.")
                    .padding(.top, OnboardingTitle.top).padding(.bottom, 20)
                VStack(spacing: 12) {
                    OnboardingCard(theme: theme) {
                        bar(theme, "5-hour", 0.42)
                        bar(theme, "Weekly", 0.18)
                    }
                    OnboardingCard(theme: theme) {
                        if isOn {
                            Label("Claude limits are on", systemImage: "checkmark.circle.fill")
                                .font(.system(size: 13, weight: .heavy, design: .rounded))
                                .foregroundStyle(theme.accent.swiftUI)
                            Text("Turn it off in Settings › Agents to put everything back.")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(theme.ink.swiftUI.opacity(0.7))
                        } else {
                            Text("What changes").font(.system(size: 13, weight: .heavy, design: .rounded))
                            bullet(theme, "TokenCats wraps your Claude Code status line once.")
                            bullet(theme, "Your current status line keeps showing as it is.")
                            bullet(theme, "The original setting is backed up next to settings.json.")
                            bullet(theme, "Turn it off in Settings › Agents to put everything back.")
                        }
                    }
                }
                .padding(.horizontal, 32)
                OnboardingNotice(theme: theme, notice: notice)
                Spacer()
                if isOn {
                    OnboardingFooter(theme: theme, primary: "Next", onPrimary: onNext)
                } else {
                    OnboardingFooter(theme: theme, primary: "Agree and turn on", secondary: "Later",
                                     onPrimary: onTurnOn, onSecondary: onNext)
                }
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

/// What the GitHub page does when its buttons are pressed.
struct OnboardingGitHubActions {
    var connect: () -> Void = {}
    var openDevicePage: () -> Void = {}
    var cancel: () -> Void = {}
    var createRepo: () -> Void = {}
    var installApp: () -> Void = {}
    var checkAgain: () -> Void = {}
    var addToReadme: () -> Void = {}
    var viewProfile: () -> Void = {}
}

struct OnboardingGitHubStep: View {
    let phase: OnboardingGitHubPhase
    let login: String
    var progress = OnboardingProgress(step: 4)
    /// The card as it will be uploaded, shown live through WebKit so its cats move.
    var cardSVG: String?
    /// A still of the card (design snapshots draw off screen, where a web view stays blank).
    var card: NSImage?
    var showsNumbers: Binding<Bool> = .constant(true)
    var showsYear: Binding<Bool> = .constant(true)
    var busy = false
    var notice: LocalizedStringResource?
    var actions = OnboardingGitHubActions()
    var onBack: () -> Void = {}
    var onNext: () -> Void = {}

    var body: some View {
        OnboardingPage { theme in
            VStack(spacing: 0) {
                OnboardingHeader(theme: theme, progress: progress, onBack: onBack, onSkip: onNext)
                OnboardingTitle(theme: theme, title: "Put your cats on GitHub",
                                subtitle: "Your cat room goes on top of your profile README\nand keeps itself up to date.")
                    .padding(.top, OnboardingTitle.top).padding(.bottom, 20)
                preview(theme)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 14)
                content(theme)
                    .padding(.horizontal, 32)
                OnboardingNotice(theme: theme, notice: notice)
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
                check(theme, "The cat room", isOn: .constant(true), locked: true)
                check(theme, "Token numbers", isOn: showsNumbers)
                check(theme, "Contribution graph and streak", isOn: showsYear)
            }
        case let .code(code):
            OnboardingCard(theme: theme) {
                Text("Code to enter in the browser").font(.system(size: 13, weight: .heavy, design: .rounded))
                HStack {
                    Text(verbatim: code).font(.system(size: 26, weight: .heavy, design: .monospaced)).textSelection(.enabled)
                    Spacer()
                    Button("Copy") { copyToClipboard(code) }
                        .buttonStyle(OnboardingSecondaryButtonStyle(theme: theme, onCard: true))
                }
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("Opened github.com/login/device. Waiting for approval…")
                }
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(theme.ink.swiftUI.opacity(0.7))
            }
        case let .needsAccess(appInstall):
            OnboardingCard(theme: theme) {
                Text("A step on GitHub").font(.system(size: 13, weight: .heavy, design: .rounded))
                task(theme, "Create your profile repo \(login)/\(login) if you don't have it", action: actions.createRepo)
                if appInstall {
                    task(theme, "Install the TokenCats App and pick that repo", action: actions.installApp)
                }
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
        case .start:
            OnboardingFooter(theme: theme, primary: "Connect with GitHub", secondary: "Later", busy: busy,
                             onPrimary: actions.connect, onSecondary: onNext)
        case .code:
            OnboardingFooter(theme: theme, primary: "Open GitHub again", secondary: "Cancel",
                             onPrimary: actions.openDevicePage, onSecondary: actions.cancel)
        case .needsAccess:
            OnboardingFooter(theme: theme, primary: "Check again", secondary: "Later", busy: busy,
                             onPrimary: actions.checkAgain, onSecondary: onNext)
        case .ready:
            OnboardingFooter(theme: theme, primary: "Add to my README", secondary: "Later", busy: busy,
                             onPrimary: actions.addToReadme, onSecondary: onNext)
        case .done:
            OnboardingFooter(theme: theme, primary: "Next", secondary: "View on GitHub",
                             onPrimary: onNext, onSecondary: actions.viewProfile)
        }
    }

    private func check(_ theme: RoomTheme, _ label: LocalizedStringKey, isOn: Binding<Bool>, locked: Bool = false) -> some View {
        Button { if !locked { isOn.wrappedValue.toggle() } } label: {
            HStack {
                Image(systemName: isOn.wrappedValue ? "checkmark.square.fill" : "square")
                    .foregroundStyle(theme.accent.swiftUI.opacity(locked ? 0.5 : 1))
                Text(label)
                if locked { Text("Always").foregroundStyle(theme.ink.swiftUI.opacity(0.5)) }
            }
        }
        .buttonStyle(.plain)
        .font(.system(size: 12, weight: .semibold, design: .rounded))
    }

    private func task(_ theme: RoomTheme, _ label: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        HStack {
            Image(systemName: "circle").foregroundStyle(theme.ink.swiftUI.opacity(0.5))
            Text(label).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Button("Open", action: action).buttonStyle(OnboardingSecondaryButtonStyle(theme: theme, onCard: true))
        }
        .font(.system(size: 12, weight: .semibold, design: .rounded))
    }
}

// MARK: - 5 Launch at login

struct OnboardingLoginItemStep: View {
    var isOn: Binding<Bool> = .constant(true)
    var progress = OnboardingProgress(step: 5)
    var onBack: () -> Void = {}
    /// Moves on without changing the setting; "Next" applies the switch.
    var onSkip: (() -> Void)?
    var onNext: () -> Void = {}

    var body: some View {
        OnboardingPage { theme in
            VStack(spacing: 0) {
                OnboardingHeader(theme: theme, progress: progress, onBack: onBack, onSkip: onSkip ?? onNext)
                OnboardingTitle(theme: theme, title: "Start with your Mac?",
                                subtitle: "Tokens spent while TokenCats is closed\ndon't turn into churu.")
                    .padding(.top, OnboardingTitle.top).padding(.bottom, 20)
                Spacer()
                Image(systemName: "power.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(theme.accent.swiftUI)
                    .padding(.bottom, 20)
                OnboardingCard(theme: theme) {
                    Toggle(isOn: isOn) {
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
    var progress = OnboardingProgress(step: 6)
    var onBack: () -> Void = {}
    var onFinish: () -> Void = {}

    var body: some View {
        OnboardingPage { theme in
            VStack(spacing: 0) {
                OnboardingHeader(theme: theme, progress: progress, onBack: onBack)
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
                            // A free store (testing) has no price to count towards.
                            if adoptionPrice > 0 {
                                Text("\(TokenCount.compact(adoptionPrice)) to your first adoption")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundStyle(theme.ink.swiftUI.opacity(0.7))
                            }
                        }
                        if adoptionPrice > 0 {
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(theme.panel.swiftUI)
                                    Capsule().fill(theme.accent.swiftUI)
                                        .frame(width: max(8, geometry.size.width
                                                          * min(1, Double(churu) / Double(adoptionPrice))))
                                }
                            }
                            .frame(height: 8)
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
