import Foundation

/// Every JSON file TokenCats keeps in its support directory, by name. The one place a file name is spelled:
/// models ask here instead of building paths, and `Backup` carries `userDataNames`.
struct DataFiles {
    let directory: URL

    static var live: DataFiles { DataFiles(directory: AppPaths.supportDirectory) }

    /// Files a backup carries: the user's cats and their bonds, churu, purchases, display choices and profile state.
    /// Session and result caches are rebuilt from the agents, so they stay out.
    static var userDataNames: [String] {
        let files = DataFiles(directory: URL(fileURLWithPath: "/"))
        return [files.cats.url, files.churu.url, files.inventory.url, files.uiDisplay.url, files.profileSync.url,
                files.bonds.url]
            .map(\.lastPathComponent)
    }

    /// Every owned cat and whether it is in the room.
    var cats: JSONFile<CatHousehold> { file("cats.json") }
    /// The churu ledger: baseline, daily tokens and balance.
    var churu: JSONFile<ChuruLedger> { file("churu.json") }
    /// Owned backgrounds and the purchase record.
    var inventory: JSONFile<StoreInventory> { file("inventory.json") }
    /// What the Home shows.
    var uiDisplay: JSONFile<UIDisplaySettings> { file("ui-display.json") }
    /// GitHub connection and the last card upload.
    var profileSync: JSONFile<ProfileSyncState> { file("profile-sync.json") }
    /// Every cat's bond level progress.
    var bonds: JSONFile<CatBondBook> { file("bonds.json") }
    /// The GitHub App token from the device flow. Never part of a backup.
    var githubToken: SecretFile<UserToken> { SecretFile(url: directory.appendingPathComponent("github-token.json")) }
    /// Day totals from the agents' logs, so the year graph does not rescan every time.
    var dailyHistory: JSONFile<DailyHistory> { file("daily-history.json") }
    /// Recent agent results shown on the Home.
    var results: JSONFile<RecentResults> { file("results.json") }
    /// Sessions from the previous run, for launch-time recovery.
    var sessions: JSONFile<[SessionSnapshot]> { file("sessions.json") }

    static func inDirectory(_ url: URL) -> DataFiles { DataFiles(directory: url) }

    private func file<Value: Codable>(_ name: String) -> JSONFile<Value> {
        JSONFile(url: directory.appendingPathComponent(name))
    }
}
