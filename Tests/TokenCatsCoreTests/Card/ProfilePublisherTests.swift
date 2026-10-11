import Foundation
import Testing
@testable import TokenCatsCore

/// Answers requests from a script keyed by "METHOD path" and records what was sent.
final class FakeTransport: HTTPTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var script: [String: [(Int, String)]]
    private(set) var sent: [URLRequest] = []

    init(_ script: [String: [(Int, String)]]) { self.script = script }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        lock.lock(); defer { lock.unlock() }
        sent.append(request)
        let key = "\(request.httpMethod ?? "GET") \(request.url!.path)"
        guard var answers = script[key], !answers.isEmpty else {
            return (Data(), HTTPURLResponse(url: request.url!, statusCode: 599, httpVersion: nil, headerFields: nil)!)
        }
        let (status, body) = answers.removeFirst()
        script[key] = answers
        return (Data(body.utf8), HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
    }

    var calls: [String] { sent.map { "\($0.httpMethod ?? "GET") \($0.url!.path)" } }

    func body(_ index: Int) -> [String: Any] {
        (try? JSONSerialization.jsonObject(with: sent[index].httpBody ?? Data())) as? [String: Any] ?? [:]
    }
}

private let repo = "/repos/neko/neko"

private func uploadScript(refStatus: Int = 200) -> [String: [(Int, String)]] {
    [
        "POST \(repo)/git/blobs": [(201, #"{"sha":"b1"}"#)],
        "POST \(repo)/git/trees": [(201, #"{"sha":"t1"}"#)],
        "POST \(repo)/git/commits": [(201, #"{"sha":"c1"}"#)],
        "PATCH \(repo)/git/refs/heads/catroom": [(refStatus, refStatus == 200 ? #"{"object":{"sha":"c1"}}"# : "{}")],
        "POST \(repo)/git/refs": [(201, #"{"object":{"sha":"c1"}}"#)],
    ]
}

struct ProfilePublisherTests {
    @Test func uploadsOneParentlessCommit() async throws {
        let transport = FakeTransport(uploadScript())
        let result = try await ProfilePublisher(api: GitHubAPI(token: "tok", transport: transport))
            .publish(svg: "<svg/>", owner: "neko", repo: "neko", lastDigest: nil)
        #expect(result == .uploaded(digest: ProfilePublisher.digest("<svg/>"), commit: "c1"))
        #expect(transport.calls == ["POST \(repo)/git/blobs", "POST \(repo)/git/trees", "POST \(repo)/git/commits",
                                    "PATCH \(repo)/git/refs/heads/catroom"])
        #expect(transport.body(0)["content"] as? String == Data("<svg/>".utf8).base64EncodedString())
        #expect(transport.body(0)["encoding"] as? String == "base64")
        let tree = try #require((transport.body(1)["tree"] as? [[String: Any]])?.first)
        #expect(tree["path"] as? String == "catroom.svg" && tree["sha"] as? String == "b1" && tree["mode"] as? String == "100644")
        #expect(transport.body(1)["base_tree"] == nil)
        #expect((transport.body(2)["parents"] as? [Any])?.isEmpty == true)
        #expect(transport.body(2)["tree"] as? String == "t1")
        #expect(transport.body(3)["sha"] as? String == "c1" && transport.body(3)["force"] as? Bool == true)
        #expect(transport.sent[0].value(forHTTPHeaderField: "Authorization") == "Bearer tok")
        #expect(transport.sent[0].value(forHTTPHeaderField: "Accept") == "application/vnd.github+json")
    }

    @Test(arguments: [404, 422])
    func createsTheBranchWhenItDoesNotExist(status: Int) async throws {
        let transport = FakeTransport(uploadScript(refStatus: status))
        _ = try await ProfilePublisher(api: GitHubAPI(token: "tok", transport: transport))
            .publish(svg: "<svg/>", owner: "neko", repo: "neko", lastDigest: nil)
        #expect(transport.calls.last == "POST \(repo)/git/refs")
        #expect(transport.body(4)["ref"] as? String == "refs/heads/catroom")
        #expect(transport.body(4)["sha"] as? String == "c1")
    }

    @Test func sameSvgSendsNothing() async throws {
        let transport = FakeTransport([:])
        let result = try await ProfilePublisher(api: GitHubAPI(token: "tok", transport: transport))
            .publish(svg: "<svg/>", owner: "neko", repo: "neko", lastDigest: ProfilePublisher.digest("<svg/>"))
        #expect(result == .unchanged)
        #expect(transport.sent.isEmpty)
    }

    @Test func digestChangesWithContent() {
        #expect(ProfilePublisher.digest("<svg/>") != ProfilePublisher.digest("<svg />"))
        #expect(ProfilePublisher.digest("<svg/>") == ProfilePublisher.digest("<svg/>"))
    }

    @Test func unauthorizedIsReported() async {
        let transport = FakeTransport(["POST \(repo)/git/blobs": [(401, "{}")]])
        await #expect(throws: GitHubError.unauthorized) {
            try await ProfilePublisher(api: GitHubAPI(token: "tok", transport: transport))
                .publish(svg: "<svg/>", owner: "neko", repo: "neko", lastDigest: nil)
        }
    }

    @Test func loginAndRepository() async throws {
        let transport = FakeTransport([
            "GET /user": [(200, #"{"login":"neko"}"#)],
            "GET \(repo)": [(200, #"{"default_branch":"main","private":false}"#)],
            "GET /repos/neko/missing": [(404, "{}")],
        ])
        let api = GitHubAPI(token: "tok", transport: transport)
        #expect(try await api.login() == "neko")
        let found = try await api.repository(owner: "neko", repo: "neko")
        #expect(found?.defaultBranch == "main" && found?.isPrivate == false)
        #expect(try await api.repository(owner: "neko", repo: "missing") == nil)
    }

    @Test func readmeRoundTrip() async throws {
        let encoded = Data("# Hi\n".utf8).base64EncodedString()
        let wrapped = String(encoded.prefix(4)) + "\\n" + String(encoded.dropFirst(4))
        let transport = FakeTransport([
            "GET \(repo)/contents/README.md": [(200, #"{"sha":"r1","content":"\#(wrapped)"}"#), (404, "{}")],
            "PUT \(repo)/contents/README.md": [(200, "{}")],
        ])
        let api = GitHubAPI(token: "tok", transport: transport)
        let readme = try #require(try await api.readme(owner: "neko", repo: "neko", branch: "main"))
        #expect(readme.text == "# Hi\n" && readme.sha == "r1")
        #expect(transport.sent[0].url?.query == "ref=main")
        #expect(try await api.readme(owner: "neko", repo: "neko", branch: "main") == nil)
        try await api.putReadme(owner: "neko", repo: "neko", branch: "main", text: "new", sha: "r1", message: "m")
        #expect(transport.body(2)["sha"] as? String == "r1")
        #expect(transport.body(2)["branch"] as? String == "main")
        #expect(transport.body(2)["content"] as? String == Data("new".utf8).base64EncodedString())
    }

    /// Over 1 MB GitHub sends no content (`encoding: none`). Reading that as an empty README would overwrite it.
    @Test func aReadmeGitHubWillNotSendIsAnErrorNotEmpty() async {
        let transport = FakeTransport([
            "GET \(repo)/contents/README.md": [(200, #"{"sha":"r1","size":1500000,"encoding":"none","content":""}"#)],
        ])
        let api = GitHubAPI(token: "tok", transport: transport)
        await #expect(throws: GitHubError.readmeTooLarge) {
            _ = try await api.readme(owner: "neko", repo: "neko", branch: "main")
        }
    }
}
