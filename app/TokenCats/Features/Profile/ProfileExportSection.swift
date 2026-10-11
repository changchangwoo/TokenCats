import SwiftUI

/// 설정 › GitHub 프로필: writes catroom.svg (the room plus a one-year graph) and shows it in Finder.
struct ProfileExportSection: View {
    @State private var notice: LocalizedStringResource?
    @State private var working = false

    var body: some View {
        Section {
            Button(working ? "Creating…" : "Create profile SVG") {
                Task { await export() }
            }
            .disabled(working)
        } header: {
            Text("SVG file")
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                if let notice { Text(notice) }
                Text("Creates the card as an SVG file with the settings above and shows it in Finder.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func export() async {
        working = true
        defer { working = false }
        if ProfileCard.needsFirstScan { notice = "Reading past records for the first time… (about 30 seconds)" }
        do {
            let url = try ProfileExport.write(try await ProfileCard.render(owner: ProfileSync.shared.state.owner))
            NSWorkspace.shared.activateFileViewerSelecting([url])
            notice = "Saved to \(url.path)"
        } catch ProfileCardError.notReady {
            notice = "The churu count is not finished yet. Try again in a moment."
        } catch let tooLarge as CatRoomSVG.TooLarge {
            notice = "Not saved: the file is \(tooLarge.bytes / 1_000) KB, over the 2 MB limit. Put fewer cat patterns in the room."
        } catch {
            notice = "Could not save: \(error.localizedDescription)"
        }
    }
}
