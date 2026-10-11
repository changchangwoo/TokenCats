import Foundation

struct DeviceCode: Equatable, Sendable {
    let deviceCode: String
    /// Shown to the user, who types it at `verificationURI`.
    let userCode: String
    let verificationURI: URL
    let interval: Int
    let expiresIn: Int
}

/// A GitHub App user token. The app is registered with token expiry turned off, because refreshing needs the
/// client secret, which a desktop app cannot keep; if GitHub still sends an expiry, the user reconnects after it.
struct UserToken: Codable, Equatable, Sendable {
    let accessToken: String
    let expiresAt: Date?

    func isExpired(now: Date) -> Bool { expiresAt.map { $0 <= now } ?? false }
}

enum DeviceFlowError: Error, Equatable {
    case denied
    case expired
    case disabled
    case unexpected(String)
}

/// GitHub's OAuth device flow: ask for a code, the user approves it in the browser, poll for the token.
/// No password ever passes through the app.
struct DeviceFlow: Sendable {
    let clientID: String
    let transport: HTTPTransport
    let sleep: @Sendable (Int) async throws -> Void
    let now: @Sendable () -> Date

    init(clientID: String, transport: HTTPTransport = URLSessionTransport(),
         sleep: @escaping @Sendable (Int) async throws -> Void = { try await Task.sleep(for: .seconds($0)) },
         now: @escaping @Sendable () -> Date = { Date() }) {
        self.clientID = clientID
        self.transport = transport
        self.sleep = sleep
        self.now = now
    }

    func start() async throws -> DeviceCode {
        let object = try await post("/login/device/code", ["client_id": clientID])
        guard let deviceCode = object["device_code"] as? String, let userCode = object["user_code"] as? String,
              let uri = (object["verification_uri"] as? String).flatMap(URL.init(string:))
        else { throw DeviceFlowError.unexpected(object["error"] as? String ?? "no device code") }
        return DeviceCode(deviceCode: deviceCode, userCode: userCode, verificationURI: uri,
                          interval: object["interval"] as? Int ?? 5, expiresIn: object["expires_in"] as? Int ?? 900)
    }

    /// Waits `interval` before every check; `slow_down` raises the interval as GitHub asks.
    func poll(_ code: DeviceCode) async throws -> UserToken {
        var interval = code.interval
        while true {
            try await sleep(interval)
            let object = try await post("/login/oauth/access_token", [
                "client_id": clientID, "device_code": code.deviceCode,
                "grant_type": "urn:ietf:params:oauth:grant-type:device_code",
            ])
            if let token = object["access_token"] as? String {
                let expiresAt = (object["expires_in"] as? Int).map { now().addingTimeInterval(TimeInterval($0)) }
                return UserToken(accessToken: token, expiresAt: expiresAt)
            }
            switch object["error"] as? String {
            case "authorization_pending": continue
            case "slow_down": interval = object["interval"] as? Int ?? interval + 5
            case "access_denied": throw DeviceFlowError.denied
            case "expired_token", "token_expired": throw DeviceFlowError.expired
            case "device_flow_disabled": throw DeviceFlowError.disabled
            case let other: throw DeviceFlowError.unexpected(other ?? "no token")
            }
        }
    }

    private func post(_ path: String, _ fields: KeyValuePairs<String, String>) async throws -> [String: Any] {
        var request = URLRequest(url: URL(string: "https://github.com\(path)")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(fields.map { "\($0.key)=\($0.value)" }.joined(separator: "&").utf8)
        let (data, response) = try await transport.send(request)
        guard (200..<300).contains(response.statusCode) else { throw DeviceFlowError.unexpected("HTTP \(response.statusCode)") }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
    }
}
