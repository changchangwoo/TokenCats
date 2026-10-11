import Foundation

/// Sends one HTTP request. The app uses `URLSessionTransport`; tests script the answers.
protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

struct URLSessionTransport: HTTPTransport {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw GitHubError.unexpected(0) }
        return (data, http)
    }
}

enum GitHubError: Error, Equatable {
    /// The token is missing, expired or revoked: reconnect rather than retry.
    case unauthorized
    case notFound
    /// GitHub's contents API sends no text for a README over 1 MB; it is never rewritten.
    case readmeTooLarge
    case unexpected(Int)
}

struct GitHubRepository: Equatable, Sendable {
    let defaultBranch: String
    let isPrivate: Bool
}

struct GitHubFile: Equatable, Sendable {
    let text: String
    let sha: String
}

/// The few GitHub REST calls the profile card needs.
struct GitHubAPI: Sendable {
    let token: String
    let transport: HTTPTransport

    init(token: String, transport: HTTPTransport = URLSessionTransport()) {
        self.token = token
        self.transport = transport
    }

    func login() async throws -> String {
        guard let login = try await call("GET", "/user")["login"] as? String else { throw GitHubError.unexpected(200) }
        return login
    }

    /// nil when the repository does not exist or the token cannot see it.
    func repository(owner: String, repo: String) async throws -> GitHubRepository? {
        do {
            let object = try await call("GET", "/repos/\(owner)/\(repo)")
            return GitHubRepository(defaultBranch: object["default_branch"] as? String ?? "main",
                                    isPrivate: object["private"] as? Bool ?? false)
        } catch GitHubError.notFound {
            return nil
        }
    }

    /// Points `branch` at a new parentless commit holding one file, so the branch never grows a history.
    /// Returns the commit SHA.
    func replaceBranch(owner: String, repo: String, branch: String, path: String, content: Data,
                       message: String) async throws -> String {
        let base = "/repos/\(owner)/\(repo)/git"
        let blob = try await sha(call("POST", "\(base)/blobs",
                                      body: ["content": content.base64EncodedString(), "encoding": "base64"]))
        let tree = try await sha(call("POST", "\(base)/trees",
                                      body: ["tree": [["path": path, "mode": "100644", "type": "blob", "sha": blob]]]))
        let commit = try await sha(call("POST", "\(base)/commits",
                                        body: ["message": message, "tree": tree, "parents": [String]()]))
        do {
            _ = try await call("PATCH", "\(base)/refs/heads/\(branch)", body: ["sha": commit, "force": true])
        } catch GitHubError.notFound, GitHubError.unexpected(422) {
            // GitHub answers 422 "Reference does not exist" (sometimes 404) for a branch that is not there yet.
            _ = try await call("POST", "\(base)/refs", body: ["ref": "refs/heads/\(branch)", "sha": commit])
        }
        return commit
    }

    /// The README on `branch`, or nil when there is none.
    func readme(owner: String, repo: String, branch: String) async throws -> GitHubFile? {
        do {
            let object = try await call("GET", "/repos/\(owner)/\(repo)/contents/README.md",
                                        query: [URLQueryItem(name: "ref", value: branch)])
            if object["encoding"] as? String == "none" { throw GitHubError.readmeTooLarge }
            guard let encoded = object["content"] as? String, let sha = object["sha"] as? String,
                  let data = Data(base64Encoded: encoded, options: .ignoreUnknownCharacters)
            else { throw GitHubError.unexpected(200) }
            return GitHubFile(text: String(decoding: data, as: UTF8.self), sha: sha)
        } catch GitHubError.notFound {
            return nil
        }
    }

    /// Creates or updates README.md on `branch`; `sha` is the current file's, nil when creating.
    func putReadme(owner: String, repo: String, branch: String, text: String, sha: String?, message: String) async throws {
        var body: [String: Any] = ["message": message, "content": Data(text.utf8).base64EncodedString(), "branch": branch]
        if let sha { body["sha"] = sha }
        _ = try await call("PUT", "/repos/\(owner)/\(repo)/contents/README.md", body: body)
    }

    private func sha(_ object: [String: Any]) throws -> String {
        guard let sha = object["sha"] as? String else { throw GitHubError.unexpected(200) }
        return sha
    }

    private func call(_ method: String, _ path: String, query: [URLQueryItem] = [],
                      body: [String: Any]? = nil) async throws -> [String: Any] {
        var components = URLComponents(string: "https://api.github.com")!
        components.path = path
        if !query.isEmpty { components.queryItems = query }
        var request = URLRequest(url: components.url!)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("TokenCats", forHTTPHeaderField: "User-Agent")
        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let (data, response) = try await transport.send(request)
        switch response.statusCode {
        case 200..<300:
            return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        case 401: throw GitHubError.unauthorized
        case 404: throw GitHubError.notFound
        default: throw GitHubError.unexpected(response.statusCode)
        }
    }
}
