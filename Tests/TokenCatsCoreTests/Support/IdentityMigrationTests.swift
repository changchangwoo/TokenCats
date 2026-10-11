import Foundation
import Testing
@testable import TokenCatsCore

/// Notch Companion → TokenCats: the data folder, settings domain, hook and status-line commands, README block.
struct IdentityMigrationTests {
    let home: URL
    let destination: URL
    init() throws {
        home = try makeTempDirectory()
        destination = home.appendingPathComponent("Library/Application Support/TokenCats", isDirectory: true)
    }

    private var legacyFolder: URL { home.appendingPathComponent(LegacyIdentity.supportFolder, isDirectory: true) }

    @Test func movesTheOldFolderAndDropsTheOldScripts() throws {
        try FileManager.default.createDirectory(at: legacyFolder, withIntermediateDirectories: true)
        try Data("{}".utf8).write(to: legacyFolder.appendingPathComponent("cats.json"))
        try Data().write(to: legacyFolder.appendingPathComponent(LegacyIdentity.hookMarker))
        #expect(IdentityMigration.moveSupportDirectory(home: home, to: destination))
        #expect(FileManager.default.fileExists(atPath: destination.appendingPathComponent("cats.json").path))
        #expect(!FileManager.default.fileExists(atPath: destination.appendingPathComponent(LegacyIdentity.hookMarker).path))
        #expect(!FileManager.default.fileExists(atPath: legacyFolder.path))
        #expect(!IdentityMigration.moveSupportDirectory(home: home, to: destination))
    }

    @Test func neverOverwritesTheNewFolder() throws {
        try FileManager.default.createDirectory(at: legacyFolder, withIntermediateDirectories: true)
        try Data("old".utf8).write(to: legacyFolder.appendingPathComponent("cats.json"))
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        try Data("new".utf8).write(to: destination.appendingPathComponent("cats.json"))
        #expect(!IdentityMigration.moveSupportDirectory(home: home, to: destination))
        #expect(try String(contentsOf: destination.appendingPathComponent("cats.json"), encoding: .utf8) == "new")
    }

    @Test func copiesOnlyMissingSettingsAndNotTheOldUpdater() {
        let copied = IdentityMigration.defaultsToCopy(
            legacy: ["firstLaunch": false, "roomThemeID": "forest", "SUEnableAutomaticChecks": true],
            existing: ["roomThemeID"])
        #expect(copied.keys.sorted() == ["firstLaunch"])
    }

    @Test func renamesTheStatusLineFirstBackup() throws {
        let settings = home.appendingPathComponent(".claude/settings.json")
        try FileManager.default.createDirectory(at: settings.deletingLastPathComponent(), withIntermediateDirectories: true)
        let legacy = settings.appendingPathExtension(LegacyIdentity.statusLineFirstBackupExtension)
        try Data("orig".utf8).write(to: legacy)
        let target = settings.appendingPathExtension("tokencats-statusline.bak")
        IdentityMigration.renameStatusLineFirstBackup(settingsURL: settings, to: target)
        #expect(try String(contentsOf: target, encoding: .utf8) == "orig")
        #expect(!FileManager.default.fileExists(atPath: legacy.path))
    }

    @Test func oldHookEntriesAreReplacedByTheNewCommand() throws {
        let config = home.appendingPathComponent("settings.json")
        let old = "/usr/bin/python3 -I '/Users/me/Library/Application Support/NotchCompanion/notch-companion-hook.py' claude"
        try HookConfigMerger.install(into: Data(#"{"hooks":{"Stop":[{"hooks":[{"type":"command","command":"warp.sh"}]}]}}"#.utf8),
                                     command: old, registrations: AgentIntegration.claudeCode.hookEvents).write(to: config)
        let sut = HookIntegration(.claudeCode, hooksFile: config, scriptURL: destination.appendingPathComponent("tokencats-hook.py"))
        #expect(sut.isInstalled())
        #expect(sut.upgradeCommandIfNeeded())
        let text = try String(contentsOf: config, encoding: .utf8)
        #expect(!text.contains(LegacyIdentity.hookMarker))
        #expect(text.contains("warp.sh"))
        let root = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: config)) as? [String: Any])
        #expect(HookConfigMerger.commands(in: root).allSatisfy { $0 == sut.command })
        try sut.uninstall()
        #expect(!sut.isInstalled())
    }

    @Test func oldStatusLineIsRepointedAndKeepsItsSettings() throws {
        let settings = home.appendingPathComponent("settings.json")
        let old = #"{"model":"opus","statusLine":{"type":"command","command":"/usr/bin/python3 -I '/old/notch-companion-statusline.py'","padding":2}}"#
        try Data(old.utf8).write(to: settings)
        let sut = StatusLineIntegration(settingsURL: settings, scriptURL: destination.appendingPathComponent("tokencats-statusline.py"),
                                        originalURL: destination.appendingPathComponent("statusline-original.json"))
        #expect(sut.isInstalled())
        #expect(sut.upgradeCommandIfNeeded())
        let root = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: settings)) as? [String: Any])
        let line = try #require(root["statusLine"] as? [String: Any])
        #expect(line["command"] as? String == sut.command)
        #expect(line["padding"] as? Int == 2)
        #expect(root["model"] as? String == "opus")
        #expect(!sut.upgradeCommandIfNeeded())
    }

    @Test func oldReadmeBlockIsReplacedAndRemovable() {
        let readme = "hi\n\n<!-- notch-companion:start -->\nold\n<!-- notch-companion:end -->\n\nbye"
        let upserted = ProfileReadme.upsert(readme, owner: "a", repo: "a")
        #expect(!upserted.contains("notch-companion"))
        #expect(upserted.hasPrefix("hi\n\n" + ProfileReadme.start))
        #expect(upserted.hasSuffix(ProfileReadme.end + "\n\nbye"))
        #expect(ProfileReadme.remove(readme) == "hi\n\nbye")
        #expect(ProfileReadme.hasBlock(readme))
        #expect(!ProfileReadme.hasBlock("hi"))
    }
}
