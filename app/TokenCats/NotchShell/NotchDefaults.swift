// NotchShell — adapted from boring.notch (TheBoredTeam, GPL-3.0). See NOTICE.md.
import SwiftUI
import Defaults

extension Defaults.Keys {
    // MARK: General
    static let menubarIcon = Key<Bool>("menubarIcon", default: true)
    static let showOnAllDisplays = Key<Bool>("showOnAllDisplays", default: false)
    static let automaticallySwitchDisplay = Key<Bool>("automaticallySwitchDisplay", default: true)
    
    // MARK: Behavior
    static let minimumHoverDuration = Key<TimeInterval>("minimumHoverDuration", default: 0.3)
    static let enableHaptics = Key<Bool>("enableHaptics", default: true)
    static let openNotchOnHover = Key<Bool>("openNotchOnHover", default: true)
    static let notchHeightMode = Key<WindowHeightMode>(
        "notchHeightMode",
        default: WindowHeightMode.matchRealNotchSize
    )
    static let nonNotchHeightMode = Key<WindowHeightMode>(
        "nonNotchHeightMode",
        default: WindowHeightMode.matchMenuBar
    )
    static let nonNotchHeight = Key<CGFloat>("nonNotchHeight", default: 32)
    static let notchHeight = Key<CGFloat>("notchHeight", default: 32)
    //static let openLastTabByDefault = Key<Bool>("openLastTabByDefault", default: false)
    static let showOnLockScreen = Key<Bool>("showOnLockScreen", default: false)
    static let hideFromScreenRecording = Key<Bool>("hideFromScreenRecording", default: false)
    /// A full-screen app on the notch's display hides the closed notch and its cats.
    static let hideOnFullscreen = Key<Bool>("hideOnFullscreen", default: true)
    
    // MARK: Appearance
    //static let alwaysShowTabs = Key<Bool>("alwaysShowTabs", default: true)
    static let settingsIconInNotch = Key<Bool>("settingsIconInNotch", default: true)
    static let enableShadow = Key<Bool>("enableShadow", default: true)
    static let cornerRadiusScaling = Key<Bool>("cornerRadiusScaling", default: true)

    
    // MARK: Gestures
    static let enableGestures = Key<Bool>("enableGestures", default: true)
    static let gestureSensitivity = Key<CGFloat>("gestureSensitivity", default: 200.0)
    
    // MARK: Advanced Settings
    // Show or hide the title bar
    static let hideTitleBar = Key<Bool>("hideTitleBar", default: true)
    
}
