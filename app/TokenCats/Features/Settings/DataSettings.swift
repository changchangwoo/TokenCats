import SwiftUI

/// 데이터: the support folder, backup, restore and reset. Restore and reset keep the current files in
/// `backups/` and restart the app.
struct DataSettings: View {
    @State private var notice: LocalizedStringResource?
    @State private var confirmingRestore: URL?
    @State private var confirmingReset = false
    @State private var confirmingResetAgain = false

    private var support: URL { AppPaths.supportDirectory }

    var body: some View {
        Form {
            Section {
                Button("Open data folder") { NSWorkspace.shared.open(support) }
            } footer: {
                Text("Cats, the churu ledger, your collection, and display settings are stored in this folder.").foregroundStyle(.secondary)
            }
            Section {
                Button("Export backup…", action: exportBackup)
                Button("Restore from backup…", action: chooseRestore)
            } header: {
                Text("Backup")
            } footer: {
                Text("Restoring moves the current data into the data folder's backups first, then restarts the app.")
                    .foregroundStyle(.secondary)
            }
            Section {
                Button("Reset…", role: .destructive) { confirmingReset = true }
            } footer: {
                Text("Returns the cats and churu history to a fresh start. The current data stays in backups.")
                    .foregroundStyle(.secondary)
            }
            if let notice {
                Section { Text(notice) }
            }
        }
        .navigationTitle("Data")
        .alert("Restore this backup?", isPresented: Binding(get: { confirmingRestore != nil },
                                                          set: { if !$0 { confirmingRestore = nil } })) {
            Button("Cancel", role: .cancel) { confirmingRestore = nil }
            Button("Restore and restart") { if let url = confirmingRestore { restore(url) } }
        } message: {
            Text(confirmingRestore?.lastPathComponent ?? "")
        }
        .alert("Reset the data?", isPresented: $confirmingReset) {
            Button("Cancel", role: .cancel) { }
            Button("Continue", role: .destructive) { confirmingResetAgain = true }
        } message: {
            Text("Cats, the churu ledger, and your backgrounds go back to a fresh start.")
        }
        .alert("Really reset the data?", isPresented: $confirmingResetAgain) {
            Button("Cancel", role: .cancel) { }
            Button("Reset and restart", role: .destructive, action: reset)
        } message: {
            Text("The current data stays in the data folder's backups.")
        }
    }

    private func exportBackup() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = AppLanguage.shared.string("Back up here")
        guard panel.runModal() == .OK, let folder = panel.url else { return }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmm"
        let destination = folder.appendingPathComponent("TokenCats-backup-\(formatter.string(from: Date()))")
        do {
            try Backup.copy(from: support, to: destination)
            NSWorkspace.shared.activateFileViewerSelecting([destination])
            notice = "Backed up to \(destination.path)"
        } catch {
            notice = "Could not back up: \(error.localizedDescription)"
        }
    }

    private func chooseRestore() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.prompt = AppLanguage.shared.string("Choose this backup")
        guard panel.runModal() == .OK, let folder = panel.url else { return }
        let hasData = Backup.files.contains {
            FileManager.default.fileExists(atPath: folder.appendingPathComponent($0).path)
        }
        guard hasData else {
            notice = "This folder has no backup files."
            return
        }
        confirmingRestore = folder
    }

    private func restore(_ folder: URL) {
        do {
            try Backup.restore(from: folder, into: support)
            Relaunch.now()
        } catch {
            notice = "Could not restore: \(error.localizedDescription)"
        }
    }

    private func reset() {
        do {
            try Backup.reset(support)
            Relaunch.now()
        } catch {
            notice = "Could not reset: \(error.localizedDescription)"
        }
    }
}
