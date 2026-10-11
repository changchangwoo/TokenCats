// NotchShell — adapted from boring.notch (TheBoredTeam, GPL-3.0). See NOTICE.md.
import Defaults
import Foundation
import SwiftUI


let shadowPadding: CGFloat = 20
let openNotchSize: CGSize = .init(width: 640, height: 190)
let statisticsNotchHeight: CGFloat = 470
/// The store and My Cats keep one height whatever Home shows.
let companionStoreNotchHeight: CGFloat = 380
/// The backing window reserves the largest Home; the visible notch follows enabled UI sections.
let windowSize: CGSize = .init(width: openNotchSize.width,
                               height: max(statisticsNotchHeight, CGFloat(HomeLayout.maximumHeight)) + shadowPadding)

func companionHomeNotchHeight() -> CGFloat {
    let display = UIDisplaySettings.load(from: DataFiles.live.uiDisplay).home
    return CGFloat(HomeLayout.height(for: display))
}

/// Open notch size per tab: the agent home gets extra height, other tabs keep boring.notch's size.
func openNotchSize(for view: NotchViews) -> CGSize {
    switch view {
    case .home: return CGSize(width: openNotchSize.width, height: companionHomeNotchHeight())
    case .statistics: return CGSize(width: openNotchSize.width, height: statisticsNotchHeight)
    case .store, .cats: return CGSize(width: openNotchSize.width, height: companionStoreNotchHeight)
    }
}
/// `top` is the outward flare where the notch meets the screen edge. The open notch has none, so its top corners sit
/// flush against the screen top instead of curling outward into points.
let cornerRadiusInsets: (opened: (top: CGFloat, bottom: CGFloat), closed: (top: CGFloat, bottom: CGFloat)) = (opened: (top: 0, bottom: 24), closed: (top: 6, bottom: 14))

@MainActor func getScreenFrame(_ screenUUID: String? = nil) -> CGRect? {
    var selectedScreen = NSScreen.main

    if let uuid = screenUUID {
        selectedScreen = NSScreen.screen(withUUID: uuid)
    }
    
    if let screen = selectedScreen {
        return screen.frame
    }
    
    return nil
}

@MainActor func getClosedNotchSize(screenUUID: String? = nil) -> CGSize {
    // Default notch size, to avoid using optionals
    var notchHeight: CGFloat = Defaults[.nonNotchHeight]
    var notchWidth: CGFloat = 185

    var selectedScreen = NSScreen.main

    if let uuid = screenUUID {
        selectedScreen = NSScreen.screen(withUUID: uuid)
    }

    // Check if the screen is available
    if let screen = selectedScreen {
        // Calculate and set the exact width of the notch
        if let topLeftNotchpadding: CGFloat = screen.auxiliaryTopLeftArea?.width,
           let topRightNotchpadding: CGFloat = screen.auxiliaryTopRightArea?.width
        {
            notchWidth = screen.frame.width - topLeftNotchpadding - topRightNotchpadding + 4
        }

        // Check if the Mac has a notch
        if screen.safeAreaInsets.top > 0 {
            // This is a display WITH a notch - use notch height settings
            notchHeight = Defaults[.notchHeight]
            if Defaults[.notchHeightMode] == .matchRealNotchSize {
                notchHeight = screen.safeAreaInsets.top
            } else if Defaults[.notchHeightMode] == .matchMenuBar {
                notchHeight = menuBarHeight(of: screen)
            }
        } else {
            // This is a display WITHOUT a notch - use non-notch height settings
            notchHeight = Defaults[.nonNotchHeight]
            if Defaults[.nonNotchHeightMode] == .matchMenuBar {
                notchHeight = menuBarHeight(of: screen)
            }
        }
    }

    return .init(width: notchWidth, height: notchHeight)
}

/// The menu bar's height on `screen`, or the status bar's when the menu bar is auto-hidden.
@MainActor private func menuBarHeight(of screen: NSScreen) -> CGFloat {
    CGFloat(ClosedNotchHeight.menuBar(measured: Double(screen.frame.maxY - screen.visibleFrame.maxY),
                                      statusBarThickness: Double(NSStatusBar.system.thickness)))
}
