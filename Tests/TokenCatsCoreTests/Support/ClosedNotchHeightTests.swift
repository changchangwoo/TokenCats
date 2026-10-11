import Testing
@testable import TokenCatsCore

struct ClosedNotchHeightTests {
    @Test func aVisibleMenuBarGivesItsOwnHeight() {
        #expect(ClosedNotchHeight.menuBar(measured: 24, statusBarThickness: 22) == 24)
        #expect(ClosedNotchHeight.menuBar(measured: 37, statusBarThickness: 22) == 37)
    }

    /// An auto-hidden menu bar measures 0; the closed notch must not vanish with it.
    @Test func anAutoHiddenMenuBarFallsBackToTheStatusBar() {
        #expect(ClosedNotchHeight.menuBar(measured: 0, statusBarThickness: 22) == 22)
        #expect(ClosedNotchHeight.menuBar(measured: -1, statusBarThickness: 0) == ClosedNotchHeight.minimum)
    }
}
