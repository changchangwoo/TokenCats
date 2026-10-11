// NotchShell — adapted from boring.notch (TheBoredTeam, GPL-3.0). See NOTICE.md.

import SwiftUI

struct OnboardingFinishView: View {
    let onFinish: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        OnboardingPage { theme in
            VStack(spacing: 0) {
                Spacer()
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(theme.accent.swiftUI)
                    .padding(.bottom, 16)
                HStack(spacing: 8) {
                    Text("All set!").font(.system(size: 28, weight: .heavy, design: .rounded))
                    PixelPaw(color: theme.accent.swiftUI, size: 22)
                }
                .padding(.bottom, 12)
                Text("Hover over the notch or press the shortcut (⌘⇧I by default) to open the cat room. Connect your agents and the GitHub profile card in Settings.")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.ink.swiftUI.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 40)
                Spacer()
                VStack(spacing: 10) {
                    Button("Done", action: onFinish)
                        .buttonStyle(OnboardingPrimaryButtonStyle(theme: theme))
                        .keyboardShortcut(.defaultAction)
                    Button(action: onOpenSettings) { Label("Open Settings", systemImage: "gearshape.fill") }
                        .buttonStyle(OnboardingSecondaryButtonStyle(theme: theme))
                }
                .padding(.bottom, 36)
            }
        }
    }
}

#Preview {
    OnboardingFinishView(onFinish: { }, onOpenSettings: { })
}
