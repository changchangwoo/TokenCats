import SwiftUI

/// 설정 › GitHub 프로필 › 자동 갱신: connect, put the card in the README, update now, disconnect.
struct GitHubConnectSection: View {
    @ObservedObject private var sync = ProfileSync.shared
    @State private var notice: LocalizedStringResource?
    @State private var confirmingReadme = false
    @State private var confirmingDisconnect = false
    /// The login waiting for the user to agree to publishing the card.
    @State private var pendingConnect: ProfileSyncState.Method?

    var body: some View {
        Section {
            if sync.state.isConnected { connectedRows } else { connectRows }
            if let code = sync.deviceCode {
                HStack {
                    Text("Code to enter in the browser")
                    Spacer()
                    Text(code.userCode).font(.title3.monospaced()).textSelection(.enabled)
                    Button("Copy") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(code.userCode, forType: .string)
                    }
                }
            }
        } header: {
            Text("GitHub profile auto-update")
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                if let notice { Text(notice) }
                Text("Uploads a single card to the catroom branch of your profile repo. Commits do not pile up, and only the marked section of the README is changed.")
                    .foregroundStyle(.secondary)
            }
        }
        .confirmationDialog("Add the cat room card to the top of your README?", isPresented: $confirmingReadme) {
            Button("Add to README") { run { try await sync.installReadme(); notice = "Added the card to your README" } }
        } message: {
            Text("Adds one image line between <!-- tokencats:start --> and end. Nothing else is changed.")
        }
        .confirmationDialog("Publish the card on your GitHub profile?", isPresented: Binding(
            get: { pendingConnect != nil }, set: { if !$0 { pendingConnect = nil } }
        ), presenting: pendingConnect) { method in
            Button("Connect and upload the card") {
                run {
                    switch method {
                    case .gh: try await sync.connect(.gh)
                    case .device: try await sync.connectWithDeviceCode()
                    }
                    notice = connectedNotice
                }
            }
        } message: { _ in
            Text(publishDisclosure)
        }
        .confirmationDialog("Disconnect from GitHub?", isPresented: $confirmingDisconnect) {
            Button("Remove from README and disconnect", role: .destructive) {
                run { await sync.disconnect(removingReadme: true); notice = "Disconnected and removed the card from your README" }
            }
            Button("Keep the card and disconnect") { run { await sync.disconnect(removingReadme: false); notice = "Disconnected" } }
        }
    }

    @ViewBuilder private var connectRows: some View {
        Button("Connect with gh login") { pendingConnect = .gh }
            .disabled(GitHubCredentials.ghPath == nil || sync.busy)
        if GitHubCredentials.deviceClientID != nil {
            Button("Connect with a GitHub code") { pendingConnect = .device }
                .disabled(sync.busy || sync.deviceCode != nil)
        }
        if GitHubCredentials.ghPath == nil && GitHubCredentials.deviceClientID == nil {
            Text("Install the gh CLI and log in to connect").foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var connectedRows: some View {
        HStack {
            Text("@\(sync.state.owner ?? "")/\(sync.state.repo ?? "")")
            Spacer()
            Text(status).foregroundStyle(.secondary)
        }
        if sync.needsAppInstall {
            Text("The TokenCats App needs access to your profile repo (\(sync.state.repo ?? "")) to upload the card. If the repo does not exist, create it first, then pick it when installing the app.")
                .foregroundStyle(.orange)
            if let install = GitHubCredentials.appInstallURL {
                Button("Install the TokenCats App and pick the repo (github.com)") { NSWorkspace.shared.open(install) }
            }
        }
        if sync.repoIsMissing, let owner = sync.state.owner {
            Button("Create profile repo (github.com)") {
                NSWorkspace.shared.open(URL(string: "https://github.com/new?name=\(owner)&visibility=public")!)
            }
            Button("Check again") { run { try await sync.recheckRepository(); notice = connectedNotice } }
                .disabled(sync.busy)
        }
        if sync.repoIsPrivate {
            Text("The repo is private, so others cannot see the card").foregroundStyle(.orange)
        }
        if !sync.state.readmeInstalled && !sync.repoIsMissing {
            Button("Add card to README…") { confirmingReadme = true }
        }
        HStack {
            Button(sync.busy ? "Uploading…" : "Update now") { run { await sync.sync() } }.disabled(sync.busy)
            Spacer()
            Button("Disconnect…") { confirmingDisconnect = true }
        }
    }

    private var publishDisclosure: String {
        let language = AppLanguage.shared
        let items = AppSettings.profileCardOptions.publicItems.map { item in
            switch item {
            case .numbers: language.string("Token numbers")
            case .year: language.string("Contribution graph and streak")
            }
        }
        let shown = ([language.string("The cat room")] + items).joined(separator: ", ")
        return language.string("Uploads the card to the catroom branch of your public profile repo (login/login) and keeps it updated. Anyone can see: \(shown). You can change what shows under Card contents below first.")
    }

    private var connectedNotice: LocalizedStringResource {
        if sync.needsAppInstall { return "Connected. Install the TokenCats App on your profile repo, then click Check again" }
        return sync.repoIsMissing ? "Connected. Create your profile repo, then click Check again" : "Connected. The card is uploaded"
    }

    private var status: LocalizedStringResource {
        if sync.busy { return ProfileCard.needsFirstScan ? "Reading past records…" : "Uploading…" }
        switch sync.state.lastError {
        case ProfileSyncState.reconnectNeeded?: return "Connection expired · reconnect"
        case let error?: return "Failed · retrying in an hour (\(error))"
        case nil:
            guard let uploaded = sync.state.lastUploadAt else { return "Not uploaded yet" }
            return "Last updated \(uploaded.formatted(.relative(presentation: .named)))"
        }
    }

    private func run(_ action: @escaping @MainActor () async throws -> Void) {
        Task { @MainActor in
            do {
                try await action()
            } catch GitHubError.unauthorized {
                // A device-flow token that stopped working needs a reconnect, not the GitHub CLI.
                notice = sync.state.method == .device ? ProfileSyncProblem.reconnect.message
                    : "No GitHub login found. Run gh auth login in Terminal, then try again"
            } catch DeviceFlowError.denied {
                notice = "Connection canceled on GitHub"
            } catch DeviceFlowError.expired {
                notice = "The code expired. Try again"
            } catch {
                notice = ProfileSyncProblem(error).message
            }
        }
    }
}
