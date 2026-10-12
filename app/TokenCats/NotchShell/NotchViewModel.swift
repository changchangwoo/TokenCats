// NotchShell — adapted from boring.notch (TheBoredTeam, GPL-3.0). See NOTICE.md.
import Combine
import Defaults
import SwiftUI

class NotchViewModel: NSObject, ObservableObject {
    @ObservedObject var coordinator = NotchCoordinator.shared

    let animationLibrary: NotchAnimations = .init()
    let animation: Animation?

    @Published private(set) var notchState: NotchState = .closed

    var cancellables: Set<AnyCancellable> = []
    
    /// A full-screen app owns this display: the closed notch hides (and collapses to nothing without a physical notch).
    @Published var hideOnClosed: Bool = false

    @Published var screenUUID: String?

    @Published var notchSize: CGSize = getClosedNotchSize()
    @Published var closedNotchSize: CGSize = getClosedNotchSize()

    // No deinit: an AnyCancellable cancels itself when the set is released.
    func destroy() {
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
    }

    init(screenUUID: String? = nil) {
        animation = animationLibrary.animation

        super.init()
        
        self.screenUUID = screenUUID
        notchSize = getClosedNotchSize(screenUUID: screenUUID)
        closedNotchSize = notchSize

        Publishers.CombineLatest3($screenUUID.compactMap { $0 }.removeDuplicates(),
                                  FullscreenDetector.shared.$fullscreenStatus.removeDuplicates(),
                                  Defaults.publisher(.hideOnFullscreen).map(\.newValue).removeDuplicates())
            .map { uuid, status, enabled in enabled && (status[uuid] ?? false) }
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] shouldHide in
                withAnimation(.smooth) { self?.hideOnClosed = shouldHide }
            }
            .store(in: &cancellables)

        
    }
    
    // Computed property for effective notch height
    var effectiveClosedNotchHeight: CGFloat {
        let currentScreen = screenUUID.flatMap { NSScreen.screen(withUUID: $0) }
        let noNotchAndFullscreen = hideOnClosed && (currentScreen?.safeAreaInsets.top ?? 0 <= 0 || currentScreen == nil)
        return noNotchAndFullscreen ? 0 : closedNotchSize.height
    }

    var chinHeight: CGFloat {
        if !Defaults[.hideTitleBar] {
            return 0
        }

        guard let currentScreen = screenUUID.flatMap({ NSScreen.screen(withUUID: $0) }) else {
            return 0
        }

        if notchState == .open { return 0 }

        let menuBarHeight = currentScreen.frame.maxY - currentScreen.visibleFrame.maxY
        let currentHeight = effectiveClosedNotchHeight

        if currentHeight == 0 { return 0 }

        return max(0, menuBarHeight - currentHeight)
    }

    func open() {
        self.notchSize = openNotchSize(for: coordinator.currentView)
        self.notchState = .open
    }

    func close() {
        self.notchSize = getClosedNotchSize(screenUUID: self.screenUUID)
        self.closedNotchSize = self.notchSize
        self.notchState = .closed

        if !coordinator.openLastTabByDefault {
            coordinator.currentView = .home
        }
    }

    /// Ends the first-run scene: the notch closes, then the onboarding window opens.
    func closeHello() {
        Task { @MainActor in
            withAnimation(animationLibrary.animation) {
                coordinator.helloAnimationRunning = false
                close()
            }
            NotificationCenter.default.post(name: .firstRunSceneFinished, object: nil)
        }
    }
}
