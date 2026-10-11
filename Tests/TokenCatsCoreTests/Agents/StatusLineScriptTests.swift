import Foundation
import Testing
@testable import TokenCatsCore

private let script = resourcesURL.appendingPathComponent("tokencats-statusline.py")
private let withLimits = #"{"model":{"display_name":"Opus"},"rate_limits":{"five_hour":{"used_percentage":42,"resets_at":1800005400},"seven_day":{"used_percentage":84,"resets_at":1800172800}}}"#

private func run(_ input: String, limits: URL, original: URL) throws -> (status: Int32, stdout: String) {
    signal(SIGPIPE, SIG_IGN)
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
    process.arguments = ["-I", script.path]
    process.environment = ["HOME": NSHomeDirectory(), "PATH": "/usr/bin:/bin",
                           "TOKENCATS_LIMITS": limits.path,
                           "TOKENCATS_STATUSLINE_ORIGINAL": original.path]
    let stdin = Pipe(), stdout = Pipe()
    process.standardInput = stdin
    process.standardOutput = stdout
    try process.run()
    stdin.fileHandleForWriting.write(Data(input.utf8))
    try stdin.fileHandleForWriting.close()
    let output = stdout.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    return (process.terminationStatus, String(decoding: output, as: UTF8.self))
}

private func original(_ command: String?, in folder: URL) throws -> URL {
    let url = folder.appendingPathComponent("statusline-original.json")
    let line: Any = command.map { ["type": "command", "command": $0] } ?? NSNull()
    try JSONSerialization.data(withJSONObject: ["statusLine": line]).write(to: url)
    return url
}

struct StatusLineScriptTests {
    @Test func savesRateLimitsAndPrintsNothingWithoutAnOriginal() throws {
        let folder = try makeTempDirectory()
        let limits = folder.appendingPathComponent("claude-limits.json")
        let result = try run(withLimits, limits: limits, original: try original(nil, in: folder))
        #expect(result.status == 0)
        #expect(result.stdout.isEmpty)
        let reading = try #require(ClaudeLimitSnapshot.read(url: limits))
        #expect(reading.windows.map(\.usedPercent) == [42, 84])
    }

    @Test func noRateLimitsMeansNoSnapshot() throws {
        let folder = try makeTempDirectory()
        let limits = folder.appendingPathComponent("claude-limits.json")
        _ = try run(#"{"model":{}}"#, limits: limits, original: try original(nil, in: folder))
        #expect(!FileManager.default.fileExists(atPath: limits.path))
    }

    @Test func originalGetsTheSameInputAndItsOutputPassesThrough() throws {
        let folder = try makeTempDirectory()
        let result = try run(withLimits, limits: folder.appendingPathComponent("claude-limits.json"),
                             original: try original("printf 'bar:'; cat", in: folder))
        #expect(result.stdout == "bar:" + withLimits)
    }

    @Test func originalStillPrintsWhenSnapshotCannotBeWritten() throws {
        let folder = try makeTempDirectory()
        let result = try run(withLimits, limits: URL(fileURLWithPath: "/nonexistent-folder/claude-limits.json"),
                             original: try original("echo ok", in: folder))
        #expect(result.stdout == "ok\n")
    }

    @Test func originalStillPrintsForBrokenInput() throws {
        let folder = try makeTempDirectory()
        let result = try run("{not json", limits: folder.appendingPathComponent("claude-limits.json"),
                             original: try original("echo ok", in: folder))
        #expect(result.stdout == "ok\n")
    }

    /// Two Claude sessions: an idle one still reporting 30% must not replace the active one's 80%.
    @Test func anOlderSessionDoesNotOverwriteANewerValue() throws {
        let folder = try makeTempDirectory()
        let limits = folder.appendingPathComponent("claude-limits.json")
        let none = try original(nil, in: folder)
        func input(_ percent: Int, resets: Int) -> String {
            #"{"rate_limits":{"five_hour":{"used_percentage":\#(percent),"resets_at":\#(resets)}}}"#
        }
        _ = try run(input(80, resets: 1_800_005_400), limits: limits, original: none)
        _ = try run(input(30, resets: 1_800_005_400), limits: limits, original: none)
        #expect(try #require(ClaudeLimitSnapshot.read(url: limits)).windows.map(\.usedPercent) == [80])
        _ = try run(input(95, resets: 1_799_990_000), limits: limits, original: none)
        #expect(try #require(ClaudeLimitSnapshot.read(url: limits)).windows.map(\.usedPercent) == [80])
        _ = try run(input(5, resets: 1_800_023_400), limits: limits, original: none)
        #expect(try #require(ClaudeLimitSnapshot.read(url: limits)).windows.map(\.usedPercent) == [5])
    }

    @Test func originalExitCodePassesThrough() throws {
        let folder = try makeTempDirectory()
        let result = try run(withLimits, limits: folder.appendingPathComponent("claude-limits.json"),
                             original: try original("echo partial; exit 3", in: folder))
        #expect(result.status == 3)
        #expect(result.stdout == "partial\n")
    }

    @Test func neverRunsItselfAsTheOriginal() throws {
        let folder = try makeTempDirectory()
        let result = try run(withLimits, limits: folder.appendingPathComponent("claude-limits.json"),
                             original: try original("/usr/bin/python3 -I '/x/notch-companion-statusline.py'", in: folder))
        #expect(result.status == 0)
        #expect(result.stdout.isEmpty)
    }
}
