import Foundation
import Testing
@testable import TokenCatsCore

struct PreferencesTests {
    @Test func qualitiesSetTheRoomsFrameRate() {
        #expect(AnimationQuality.smooth.framesPerSecond == 12)
        #expect(AnimationQuality.balanced.framesPerSecond == 8)
        #expect(AnimationQuality.saver.framesPerSecond == 4)
        #expect(AnimationQuality(rawValue: "unknown") == nil)
        #expect(AnimationQuality.default == .smooth)
    }

    @Test func batterySaverDropsToSaverAndStopsBlinking() {
        let plugged = PowerPolicy.effective(quality: .smooth, saverEnabled: true, onBattery: false, lowPower: false)
        #expect(plugged == .init(quality: .smooth, blinks: true))
        let battery = PowerPolicy.effective(quality: .smooth, saverEnabled: true, onBattery: true, lowPower: false)
        #expect(battery == .init(quality: .saver, blinks: false))
        let lowPower = PowerPolicy.effective(quality: .balanced, saverEnabled: true, onBattery: false, lowPower: true)
        #expect(lowPower == .init(quality: .saver, blinks: false))
        let off = PowerPolicy.effective(quality: .balanced, saverEnabled: false, onBattery: true, lowPower: true)
        #expect(off == .init(quality: .balanced, blinks: true))
    }

    /// The card shows everything by default: the numbers are the point of sharing it.
    @Test func cardOptionsDefaultToEverythingOn() {
        #expect(ProfileCardOptions.default == ProfileCardOptions(showsNumbers: true, showsYear: true))
    }

    /// New users get the room cats on the closed notch, blinking, battery saver, and a full card.
    @Test func defaultsFavourTheCatsAndTheBattery() {
        #expect(PreferenceDefaults.closedNotchCats && PreferenceDefaults.closedNotchBlink && PreferenceDefaults.batterySaver)
        #expect(!PreferenceDefaults.sessionAlerts)
        #expect(PreferenceDefaults.profileShowsNumbers && PreferenceDefaults.profileShowsYear)
        #expect(PreferenceDefaults.language == "system")
        #expect(PreferenceDefaults.animationQuality == AnimationQuality.default.rawValue)
        #expect(PreferenceDefaults.profileSyncMode == ProfileSyncMode.default.rawValue)
        #expect(PreferenceDefaults.roomTheme == RoomThemeCatalog.bundled.defaultID)
    }

    /// boring.notch's "cool face while inactive" switch used to hide the closed-notch cats too. A user who had
    /// turned it off keeps that choice once, unless they already chose for the cats themselves.
    @Test func legacyFaceSwitchBecomesTheClosedNotchCatsChoiceOnce() {
        #expect(PreferenceMigration.closedNotchCats(legacyShowFace: false, current: nil) == false)
        #expect(PreferenceMigration.closedNotchCats(legacyShowFace: true, current: nil) == nil)
        #expect(PreferenceMigration.closedNotchCats(legacyShowFace: nil, current: nil) == nil)
        #expect(PreferenceMigration.closedNotchCats(legacyShowFace: false, current: true) == nil)
    }
}

struct ProfileSyncModeTests {
    private let calendar = Calendar(identifier: .gregorian)
    private let morning = Date(timeIntervalSince1970: 1_800_000_000)

    private func uploaded(at date: Date) -> ProfileSyncState {
        var state = ProfileSyncState(method: .gh, owner: "neko", repo: "neko")
        state.lastUploadAt = date
        state.lastThemeID = "cozy"
        return state
    }

    @Test func changesModeFollowsTheRoom() {
        let state = uploaded(at: morning)
        #expect(ProfileSyncPolicy.shouldSync(state, now: morning.addingTimeInterval(60),
                                             catsModified: morning.addingTimeInterval(30), themeID: "cozy",
                                             mode: .changes, calendar: calendar))
    }

    @Test func dailyModeIgnoresChangesWithinTheDay() {
        let state = uploaded(at: morning)
        #expect(!ProfileSyncPolicy.shouldSync(state, now: morning.addingTimeInterval(60),
                                              catsModified: morning.addingTimeInterval(30), themeID: "night",
                                              mode: .daily, calendar: calendar))
        #expect(ProfileSyncPolicy.shouldSync(state, now: morning.addingTimeInterval(2 * 86_400), catsModified: nil,
                                             themeID: "cozy", mode: .daily, calendar: calendar))
    }

    @Test func manualModeNeverSyncsByItself() {
        #expect(!ProfileSyncPolicy.shouldSync(uploaded(at: morning), now: morning.addingTimeInterval(9 * 86_400),
                                              catsModified: nil, themeID: "night", mode: .manual, calendar: calendar))
        #expect(!ProfileSyncPolicy.shouldSync(ProfileSyncState(method: .gh, owner: "neko", repo: "neko"),
                                              now: morning, catsModified: nil, themeID: nil, mode: .manual,
                                              calendar: calendar))
    }
}

struct BackupTests {
    private func supportDir() throws -> URL {
        let dir = try makeTempDirectory()
        for name in Backup.files { try Data(name.utf8).write(to: dir.appendingPathComponent(name)) }
        try Data("sock".utf8).write(to: dir.appendingPathComponent("companion.sock"))
        return dir
    }

    @Test func backupCopiesOnlyTheCompanionData() throws {
        let dir = try supportDir()
        let out = try makeTempDirectory().appendingPathComponent("backup")
        try Backup.copy(from: dir, to: out)
        #expect(Set(try FileManager.default.contentsOfDirectory(atPath: out.path)) == Set(Backup.files))
        #expect(Backup.files.contains("cats.json") && Backup.files.contains("inventory.json"))
    }

    @Test func restoreKeepsTheCurrentDataAsideFirst() throws {
        let dir = try supportDir()
        let source = try makeTempDirectory()
        try Data("restored".utf8).write(to: source.appendingPathComponent("cats.json"))
        let aside = try Backup.restore(from: source, into: dir, now: Date(timeIntervalSince1970: 0))
        #expect(try String(contentsOf: dir.appendingPathComponent("cats.json"), encoding: .utf8) == "restored")
        #expect(try String(contentsOf: aside.appendingPathComponent("cats.json"), encoding: .utf8) == "cats.json")
        #expect(aside.lastPathComponent.hasPrefix("before-restore-"))
        // Files the backup did not carry are left as they were.
        #expect(FileManager.default.fileExists(atPath: dir.appendingPathComponent("churu.json").path))
    }

    @Test func resetMovesTheDataAside() throws {
        let dir = try supportDir()
        let aside = try Backup.reset(dir, now: Date(timeIntervalSince1970: 0))
        for name in Backup.files {
            #expect(!FileManager.default.fileExists(atPath: dir.appendingPathComponent(name).path))
            #expect(FileManager.default.fileExists(atPath: aside.appendingPathComponent(name).path))
        }
        #expect(FileManager.default.fileExists(atPath: dir.appendingPathComponent("companion.sock").path))
    }
}

struct ProfileCardDisclosureTests {
    @Test func listsWhatTheCardMakesPublic() {
        #expect(ProfileCardOptions.default.publicItems == [.numbers, .year])
        #expect(ProfileCardOptions(showsNumbers: false, showsYear: true).publicItems == [.year])
        #expect(ProfileCardOptions(showsNumbers: false, showsYear: false).publicItems.isEmpty)
    }
}
