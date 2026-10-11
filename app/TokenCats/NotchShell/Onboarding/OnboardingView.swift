// NotchShell — adapted from boring.notch (TheBoredTeam, GPL-3.0). See NOTICE.md.
import SwiftUI

/// First launch: a welcome, then where to find things. TokenCats needs no system permissions.
enum OnboardingStep {
    case welcome
    case finished
}

struct OnboardingView: View {
    @State var step: OnboardingStep = .welcome
    let onFinish: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        ZStack {
            switch step {
            case .welcome:
                WelcomeView {
                    // Until this flips, the notch ignores hover and every launch replays the welcome.
                    NotchCoordinator.shared.firstLaunch = false
                    withAnimation(.easeInOut(duration: 0.6)) { step = .finished }
                }
                    .transition(.opacity)
            case .finished:
                OnboardingFinishView(onFinish: onFinish, onOpenSettings: onOpenSettings)
            }
        }
        .frame(width: 400, height: 600)
    }
}
