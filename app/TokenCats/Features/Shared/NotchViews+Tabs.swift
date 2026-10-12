import Foundation

/// One header tab: which view it opens, its label key and its SF Symbol.
struct NotchTab: Sendable {
    let view: NotchViews
    let label: String
    let icon: String
}

extension NotchViews {
    /// Tabs in the header, in order. The store and cats open from their own buttons.
    static let tabs: [NotchTab] = [
        NotchTab(view: .home, label: "Home", icon: "house.fill"),
        NotchTab(view: .statistics, label: "Stats", icon: "chart.bar.fill"),
    ]

    private var storageName: String {
        switch self {
        case .home, .store, .cats: return "home"  // the store and cats are never restored
        case .statistics: return "statistics"
        }
    }

    /// Last tab the user opened.
    static var lastSelected: NotchViews? {
        get {
            let name = UserDefaults.standard.string(forKey: AppSettings.Key.lastNotchTab)
                .map { $0 == "agents" ? "home" : $0 }  // the old Agents tab is the Home now
            return [NotchViews.home, .statistics].first { $0.storageName == name }
        }
        set {
            UserDefaults.standard.set(newValue?.storageName, forKey: AppSettings.Key.lastNotchTab)
        }
    }
}
