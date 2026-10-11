import Foundation

/// Carries a "Notch Companion" install over to TokenCats: preferences, the data folder, then the hook and
/// status-line commands. `beforeLaunch` must run before anything reads UserDefaults or the data folder.
enum LegacyDataMigration {
    /// Debug runs pointed at a copy of the data (snapshots, tests, `NC_SUPPORT_DIR`). They must never move the
    /// real folder or point the user's real agent configs at the copy. Always false in Release.
    static var isIsolatedDebugRun: Bool {
        #if DEBUG
        let environment = ProcessInfo.processInfo.environment
        return environment["NC_SNAPSHOT_DIR"] != nil || environment["NC_SUPPORT_DIR"]?.isEmpty == false
        #else
        return false
        #endif
    }

    static func beforeLaunch() {
        if isIsolatedDebugRun { return }
        let defaults = UserDefaults.standard
        if !defaults.bool(forKey: AppSettings.Key.identityMigrated) {
            if let legacy = defaults.persistentDomain(forName: LegacyIdentity.bundleID) {
                let existing = Set(defaults.dictionaryRepresentation().keys)
                IdentityMigration.defaultsToCopy(legacy: legacy, existing: existing)
                    .forEach { defaults.set($1, forKey: $0) }
            }
            defaults.set(true, forKey: AppSettings.Key.identityMigrated)
        }
        let home = FileManager.default.homeDirectoryForCurrentUser
        IdentityMigration.moveSupportDirectory(home: home, to: AppPaths.supportDirectory)
        let claudeSettings = home.appendingPathComponent(".claude/settings.json")
        IdentityMigration.renameStatusLineFirstBackup(settingsURL: claudeSettings,
                                                      to: StatusLineIntegration.claude.firstBackupURL)
    }

    /// Rewrites connected agents to the current commands. If a config could not be rewritten (e.g. broken JSON)
    /// and still runs the old unguarded command, the script is put back at its old path so that command keeps
    /// exiting 0 instead of blocking the agent.
    static func upgradeAgentCommands(hookScript: URL?, statusLineScript: URL?) {
        if isIsolatedDebugRun { return }
        if let hookScript { HookIntegration.refreshInstalledScript(from: hookScript) }
        if let statusLineScript { StatusLineIntegration.refreshInstalledScript(from: statusLineScript) }
        for agent in AgentIntegration.allCases {
            let integration = HookIntegration(agent)
            integration.upgradeCommandIfNeeded()
            guard let hookScript, let data = integration.file.read(),
                  String(decoding: data, as: UTF8.self).contains(LegacyIdentity.hookMarker) else { continue }
            let legacyScript = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(LegacyIdentity.supportFolder, isDirectory: true)
                .appendingPathComponent(LegacyIdentity.hookMarker)
            try? HookIntegration.copyScript(from: hookScript, to: legacyScript)
        }
        StatusLineIntegration.claude.upgradeCommandIfNeeded()
    }
}
