import CoreGraphics
import Testing
@testable import TokenCatsCore

struct MenuBarPanelPlacementTests {
    /// A 1440×900 screen whose menu bar takes the top 25 points.
    let visible = CGRect(x: 0, y: 0, width: 1440, height: 875)
    let panel = CGSize(width: 640, height: 500)
    let icon = CGRect(x: 400, y: 877, width: 30, height: 22)

    /// Like a system menu bar window: the leading edge lines up with the icon, a small gap below the menu bar.
    @Test func startsAtTheIconAndHangsJustBelowTheMenuBar() {
        let origin = MenuBarPanelPlacement.origin(icon: icon, visibleFrame: visible, panelSize: panel)
        #expect(origin == CGPoint(x: 400, y: 875 - MenuBarPanelPlacement.gap - 500))
    }

    @Test func clampsToTheRightEdge() {
        let right = CGRect(x: 1400, y: 877, width: 30, height: 22)
        let origin = MenuBarPanelPlacement.origin(icon: right, visibleFrame: visible, panelSize: panel)
        #expect(origin.x == 1440 - MenuBarPanelPlacement.margin - 640)
    }

    @Test func clampsToTheLeftEdge() {
        let left = CGRect(x: -10, y: 877, width: 30, height: 22)
        let origin = MenuBarPanelPlacement.origin(icon: left, visibleFrame: visible, panelSize: panel)
        #expect(origin.x == MenuBarPanelPlacement.margin)
    }

    /// A secondary display to the left of the main one has negative x.
    @Test func worksOnADisplayLeftOfTheMainOne() {
        let screen = CGRect(x: -1920, y: 0, width: 1920, height: 1055)
        let item = CGRect(x: -100, y: 1057, width: 30, height: 22)
        let origin = MenuBarPanelPlacement.origin(icon: item, visibleFrame: screen, panelSize: panel)
        #expect(origin.x == -MenuBarPanelPlacement.margin - 640)
    }
}
