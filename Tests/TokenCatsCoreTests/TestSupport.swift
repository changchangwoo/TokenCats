import Foundation
@testable import TokenCatsCore

final class FakeInspector: ProcessInspector, @unchecked Sendable {
    var details: [Int32: ProcessDetail]
    init(_ details: [Int32: ProcessDetail]) { self.details = details }
    func detail(of pid: Int32) -> ProcessDetail? { details[pid] }
    var pids: [Int32] = []
    var environments: [Int32: [String: String]] = [:]
    var openFiles: [Int32: [String]] = [:]
    func allPids() -> [Int32] { pids.isEmpty ? Array(details.keys) : pids }
    func environment(of pid: Int32) -> [String: String] { environments[pid] ?? [:] }
    func openFilePaths(of pid: Int32) -> [String] { openFiles[pid] ?? [] }
}

func makeTempDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("nc-\(UUID().uuidString.prefix(8))", isDirectory: true)
    try FileManager.default.createDirectory(
        at: url, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
    return url
}

/// Repository root: the nearest ancestor of this file that holds Package.swift, so tests may move between folders.
let repoRoot: URL = {
    var url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    while !FileManager.default.fileExists(atPath: url.appendingPathComponent("Package.swift").path), url.path != "/" {
        url = url.deletingLastPathComponent()
    }
    return url
}()

/// The app's bundled resources (catalogs, art, scripts), read straight from the tree.
let resourcesURL = repoRoot.appendingPathComponent("app/TokenCats/Resources")

let hookScriptURL = resourcesURL.appendingPathComponent("tokencats-hook.py")

struct ScriptRun {
    let status: Int32
    let stdout: String
    let elapsed: TimeInterval
}

func runHookScript(socketPath: String, provider: String, input: String, env extra: [String: String] = [:]) throws -> ScriptRun {
    // The script may exit before reading stdin; writing to its closed pipe must not kill the test process.
    signal(SIGPIPE, SIG_IGN)
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
    process.arguments = ["-I", hookScriptURL.path, provider]
    var env = ["HOME": NSHomeDirectory(), "PATH": "/usr/bin:/bin", "TOKENCATS_SOCKET": socketPath]
    env.merge(extra) { _, new in new }
    process.environment = env
    let stdin = Pipe()
    let stdout = Pipe()
    process.standardInput = stdin
    process.standardOutput = stdout
    let start = Date()
    try process.run()
    stdin.fileHandleForWriting.write(Data(input.utf8))
    try stdin.fileHandleForWriting.close()
    let output = stdout.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    return ScriptRun(status: process.terminationStatus, stdout: String(decoding: output, as: UTF8.self), elapsed: Date().timeIntervalSince(start))
}

/// A background without pictures (the former pool palette), for tests that need a plain-colour room.
let plainTheme = RoomTheme(
    id: "plain",
    colors: RoomColors(wall: SceneColor(red: 207, green: 233, blue: 242), floor: SceneColor(red: 95, green: 179, blue: 204),
                       edge: SceneColor(red: 20, green: 64, blue: 84), panel: SceneColor(red: 30, green: 88, blue: 112),
                       ink: SceneColor(red: 240, green: 250, blue: 252), accent: SceneColor(red: 255, green: 222, blue: 186),
                       stamp: SceneColor(red: 168, green: 74, blue: 52)),
    levels: [SceneColor(red: 22, green: 70, blue: 92), SceneColor(red: 214, green: 120, blue: 98),
             SceneColor(red: 243, green: 160, blue: 128), SceneColor(red: 255, green: 222, blue: 186)])
