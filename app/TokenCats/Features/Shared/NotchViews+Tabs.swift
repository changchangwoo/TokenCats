import Foundation

extension NotchViews {
    /// Tabs in the header, in order. The store and cats open from their own buttons.
    static let tabs: [(view: NotchViews, label: String, icon: String)] = [
        (.home, "Home", "house.fill"),
        (.statistics, "Stats", "chart.bar.fill"),
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
