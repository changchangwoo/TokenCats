import SwiftUI

/// The first-run window wears the applied room's palette, the same roles the notch uses: the panel as the page,
/// the darker surface for cards, ink for text and the accent for the one action. A new install has the cozy room.
struct OnboardingPage<Content: View>: View {
    @ObservedObject private var store = StoreModel.shared
    @ViewBuilder let content: (RoomTheme) -> Content

    var body: some View {
        let theme = store.theme(id: AppSettings.roomThemeID)
        content(theme)
            .foregroundStyle(theme.ink.swiftUI)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.panel.swiftUI.ignoresSafeArea())
    }
}

/// The page's main button: accent fill, panel-coloured label, rounded like the notch's buttons.
struct OnboardingPrimaryButtonStyle: ButtonStyle {
    let theme: RoomTheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .heavy, design: .rounded))
            .foregroundStyle(theme.surface.swiftUI)
            .padding(.horizontal, 28).padding(.vertical, 10)
            .background(Capsule().fill(theme.accent.swiftUI.opacity(configuration.isPressed ? 0.8 : 1)))
    }
}

/// A quieter button: on the page it sits on the darker surface; inside a card (`onCard`) on the page colour.
/// Next to the main button it is the same height, so a pair of buttons lines up.
struct OnboardingSecondaryButtonStyle: ButtonStyle {
    let theme: RoomTheme
    var onCard = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: onCard ? 13 : 14, weight: .bold, design: .rounded))
            .foregroundStyle(theme.ink.swiftUI.opacity(0.9))
            .padding(.horizontal, onCard ? 20 : 24).padding(.vertical, onCard ? 8 : 10)
            .background(Capsule().fill((onCard ? theme.panel : theme.surface).swiftUI
                    .opacity(configuration.isPressed ? 0.7 : 1)))
    }
}

/// An on/off switch in the room's colours (the system switch ignores the accent).
struct OnboardingSwitchStyle: ToggleStyle {
    let theme: RoomTheme

    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            Spacer()
            Capsule()
                .fill(configuration.isOn ? theme.accent.swiftUI : theme.panel.swiftUI)
                .frame(width: 44, height: 26)
                .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                    Circle().fill(configuration.isOn ? theme.surface.swiftUI : theme.ink.swiftUI.opacity(0.6))
                        .padding(3)
                }
                .onTapGesture { withAnimation(.easeOut(duration: 0.15)) { configuration.isOn.toggle() } }
        }
    }
}
