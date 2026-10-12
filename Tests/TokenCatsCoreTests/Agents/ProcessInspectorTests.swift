import Darwin
import Foundation
import Testing
@testable import TokenCatsCore

struct SystemProcessInspectorTests {
    @Test func systemInspectorReadsOwnEnvironmentAndFiles() throws {
        let inspector = SystemProcessInspector()
        let me = getpid()
        #expect(inspector.allPids().contains(me))
        #expect(inspector.environment(of: me)["HOME"] == NSHomeDirectory())
        let url = try makeTempDirectory().appendingPathComponent("open.txt")
        FileManager.default.createFile(atPath: url.path, contents: Data())
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        #expect(inspector.openFilePaths(of: me).contains { $0.hasSuffix("/open.txt") })
    }

    @Test func readsOwnProcess() throws {
        let inspector = SystemProcessInspector()
        let detail = try #require(inspector.detail(of: getpid()))
        #expect(detail.cwd == FileManager.default.currentDirectoryPath)
        #expect(!detail.command.isEmpty)
        #expect(detail.startedAt == inspector.detail(of: getpid())?.startedAt)
    }

    @Test func readsChildProcessCommandAndCwd() throws {
        let dir = try makeTempDirectory()
        let child = Process()
        child.executableURL = URL(fileURLWithPath: "/bin/sleep")
        child.arguments = ["5"]
        child.currentDirectoryURL = dir
        try child.run()
        defer { child.terminate() }
        let detail = try #require(SystemProcessInspector().detail(of: child.processIdentifier))
        #expect(detail.command == "/bin/sleep 5")
        #expect(detail.cwd == "/private" + dir.resolvingSymlinksInPath().path)  // kernel reports the real /private/var path
        #expect(detail.tty == nil)
        #expect(detail.parentPid == getpid())
        #expect(detail.name == "sleep")
    }

    @Test func missingProcessIsNil() {
        #expect(SystemProcessInspector().detail(of: 999_999) == nil)
        #expect(SystemProcessInspector().startedAt(of: 999_999) == nil)
    }

    /// The cheap liveness read agrees with the full detail, so a session is never pruned by a mismatch.
    @Test func startedAtMatchesTheFullDetail() throws {
        let inspector = SystemProcessInspector()
        let me = ProcessInfo.processInfo.processIdentifier
        #expect(try #require(inspector.startedAt(of: me)) == #require(inspector.detail(of: me)).startedAt)
    }
}

