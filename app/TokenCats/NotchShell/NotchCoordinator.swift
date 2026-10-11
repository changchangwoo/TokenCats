// NotchShell — adapted from boring.notch (TheBoredTeam, GPL-3.0). See NOTICE.md.
import AppKit
import Combine
import SwiftUI

/// App-wide notch state shared by every notch window: which tab is open, which display is preferred, and the
/// first-launch hello animation.
@MainActor
class NotchCoordinator: ObservableObject {
    static let shared = NotchCoordinator()

    /// Restored from the last session so the notch reopens on the tab the user left it on.
    @Published var currentView: NotchViews = NotchViews.lastSelected ?? .home {
        didSet { NotchViews.lastSelected = currentView }
    }
    @Published var helloAnimationRunning: Bool = false

    @AppStorage("firstLaunch") var firstLaunch: Bool = true

    @AppStorage("openLastTabByDefault") var openLastTabByDefault: Bool = true

    // Legacy storage for migration
    @AppStorage("preferred_screen_name") private var legacyPreferredScreenName: String?

    @AppStorage("preferred_screen_uuid") var preferredScreenUUID: String? {
        didSet {
            if let uuid = preferredScreenUUID { selectedScreenUUID = uuid }
            NotificationCenter.default.post(name: Notification.Name.selectedScreenChanged, object: nil)
        }
    }

    @Published var selectedScreenUUID: String = NSScreen.main?.displayUUID ?? ""

    private init() {
        // Migrate the display preference from its name to its UUID.
        if preferredScreenUUID == nil, let legacyName = legacyPreferredScreenName {
            if let screen = NSScreen.screens.first(where: { $0.localizedName == legacyName }),
               let uuid = screen.displayUUID {
                preferredScreenUUID = uuid
            } else {
                preferredScreenUUID = NSScreen.firstChoiceUUID
            }
            legacyPreferredScreenName = nil
        } else if preferredScreenUUID == nil {
            preferredScreenUUID = NSScreen.firstChoiceUUID
        }
        selectedScreenUUID = preferredScreenUUID ?? NSScreen.main?.displayUUID ?? ""
        helloAnimationRunning = firstLaunch
    }
}
