import Foundation

enum ServiceStatus: Equatable, Sendable {
    case incident(String)
    case operational
    case unavailable
}

/// Reads the public Claude status summary. Only Claude Code and its API are relevant to a Code failure.
struct ServiceStatusClient: Sendable {
    var transport: HTTPTransport = URLSessionTransport()

    func claudeCode() async -> ServiceStatus {
        await status(host: "status.claude.com", components: ["Claude Code", "Claude API (api.anthropic.com)"])
    }

    /// OpenAI currently publishes a Codex Desktop component, not a separate Codex CLI component.
    func codex() async -> ServiceStatus {
        await status(host: "status.openai.com", components: ["Codex in ChatGPT Desktop"])
    }

    private func status(host: String, components names: [String]) async -> ServiceStatus {
        var request = URLRequest(url: URL(string: "https://\(host)/api/v2/summary.json")!)
        request.timeoutInterval = 5
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        do {
            let (data, response) = try await transport.send(request)
            guard response.statusCode == 200,
                  let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let components = object["components"] as? [[String: Any]] else { return .unavailable }
            let relevant = components.compactMap { component -> (String, String)? in
                guard let name = component["name"] as? String,
                      let status = component["status"] as? String,
                      names.contains(name) else { return nil }
                return (name, status)
            }
            guard relevant.count == names.count else { return .unavailable }
            if let affected = relevant.first(where: { $0.1 != "operational" }) { return .incident(affected.0) }
            return .operational
        } catch {
            return .unavailable
        }
    }
}
