// NotchShell — adapted from boring.notch (TheBoredTeam, GPL-3.0). See NOTICE.md.
import SwiftUI

struct WelcomeView: View {
    var onGetStarted: (() -> Void)? = nil

    var body: some View {
        OnboardingPage { theme in
            VStack(spacing: 0) {
                Spacer()
                // The user's own room and first cat, the same picture the notch will show.
                RoomPreview(theme: theme)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(theme.panelEdge.swiftUI, lineWidth: 2))
                    .padding(.horizontal, 28)
                    .padding(.bottom, 28)
                HStack(spacing: 10) {
                    Text(verbatim: "TokenCats").font(.system(size: 30, weight: .heavy, design: .rounded))
                    PixelPaw(color: theme.accent.swiftUI, size: 24)
                }
                .padding(.bottom, 10)
                Text("Tokens you spend on coding agents turn into churu,\nand churu adopts cats that live in your notch.")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.ink.swiftUI.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.bottom, 32)
                Button("Get started") { onGetStarted?() }
                    .buttonStyle(OnboardingPrimaryButtonStyle(theme: theme))
                    .keyboardShortcut(.defaultAction)
                Spacer()
            }
        }
    }
}

#Preview {
    WelcomeView()
}
