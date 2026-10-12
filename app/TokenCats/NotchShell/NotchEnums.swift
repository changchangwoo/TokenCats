// NotchShell — adapted from boring.notch (TheBoredTeam, GPL-3.0). See NOTICE.md.
import Foundation
import Defaults

public enum NotchState {
    case closed
    case open
}

public enum NotchViews: Sendable {
    case home
    case statistics
    case store
    case cats
}

enum WindowHeightMode: String, Defaults.Serializable {
    case matchMenuBar = "Match menubar height"
    case matchRealNotchSize = "Match real notch height"
    case custom = "Custom height"
}
