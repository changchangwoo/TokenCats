// NotchShell — adapted from boring.notch (TheBoredTeam, GPL-3.0). See NOTICE.md.
import SwiftUI

/// The body of the open screens — Home, Statistics, Store or Collection, whichever tab is current. Shared by the
/// notch and the menu bar panel; the host provides the `NotchViewModel` environment object.
struct CompanionTabContent: View {
    @ObservedObject var coordinator = NotchCoordinator.shared

    var body: some View {
        ZStack(alignment: .top) {
            Group {
                switch coordinator.currentView {
                case .home:
                    HomeView()
                case .statistics:
                    StatisticsTabView()
                case .store:
                    StoreView()
                case .cats:
                    MyCatsView()
                }
            }
            .id(coordinator.currentView)
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .offset(y: 8)),
                removal: .opacity.combined(with: .offset(y: -8))))
        }
        .animation(.smooth(duration: 0.28), value: coordinator.currentView)
    }
}
