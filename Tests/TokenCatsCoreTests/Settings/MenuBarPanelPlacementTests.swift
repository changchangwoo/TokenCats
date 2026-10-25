import CoreGraphics
import Testing
@testable import TokenCatsCore

struct MenuBarPanelPlacementTests {
    /// A 1440×900 screen whose menu bar takes the top 25 points.
    let visible = CGRect(x: 0, y: 0, width: 1440, height: 875)
    let panel = CGSize(width: 680, height: 500)

    @Test func centresUnderTheIconAndHangsFromTheMenuBar() {
        let origin = MenuBarPanelPlacement.origin(iconMidX: 720, visibleFrame: visible, panelSize: panel)
        #expect(origin == CGPoint(x: 380, y: 375))
    }

    @Test func clampsToTheRightEdge() {
        let origin = MenuBarPanelPlacement.origin(iconMidX: 1420, visibleFrame: visible, panelSize: panel)
        #expect(origin.x == 760)
    }

    @Test func clampsToTheLeftEdge() {
        let origin = MenuBarPanelPlacement.origin(iconMidX: 10, visibleFrame: visible, panelSize: panel)
        #expect(origin.x == 0)
    }

    /// A secondary display to the left of the main one has negative x.
    @Test func worksOnADisplayLeftOfTheMainOne() {
        let left = CGRect(x: -1920, y: 0, width: 1920, height: 1055)
        let origin = MenuBarPanelPlacement.origin(iconMidX: -100, visibleFrame: left, panelSize: panel)
        #expect(origin == CGPoint(x: -680, y: 555))
    }
}
