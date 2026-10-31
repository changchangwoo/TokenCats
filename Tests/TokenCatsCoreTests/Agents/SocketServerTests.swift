import Foundation
import Testing
@testable import TokenCatsCore

/// Two copies of the app share one socket path: a relaunch runs the new copy before the old one quits, and a
/// Debug build can run beside the installed app. Hooks reach whichever copy owns the socket file at that moment.
struct SocketHandoffTests {
    private static let stopEvent = #"{"hook_event_name":"Stop","session_id":"s","cwd":"/tmp"}"#

    @Test func theCopyThatBoundTheSocketRemovesItWhenItQuits() throws {
        let path = try makeTempDirectory().appendingPathComponent("own.sock").path
        let server = SocketServer(socketPath: path, clientReadTimeout: 0.5)
        server.start { _ in nil }
        #expect(Self.wait { FileManager.default.fileExists(atPath: path) })

        server.stop()
        #expect(Self.wait { !FileManager.default.fileExists(atPath: path) })
    }

    @Test func aCopyThatNeverGotTheSocketLeavesItInPlaceWhenItQuits() throws {
        let path = try makeTempDirectory().appendingPathComponent("shared.sock").path
        let running = SocketServer(socketPath: path, clientReadTimeout: 0.5)
        let received = Box<HookEnvelope?>(nil)
        running.start { envelope in received.value = envelope; return nil }
        defer { running.stop() }
        #expect(Self.wait { FileManager.default.fileExists(atPath: path) })

        // The second copy finds the socket busy, so it never binds; quitting it must not take the first copy's file.
        let second = SocketServer(socketPath: path, clientReadTimeout: 0.5)
        second.start { _ in nil }
        Thread.sleep(forTimeInterval: 0.1)
        second.stop()
        Thread.sleep(forTimeInterval: 0.1)
        #expect(FileManager.default.fileExists(atPath: path))

        _ = try runHookScript(socketPath: path, provider: "claude", input: Self.stopEvent)
        #expect(Self.wait { received.value != nil })
        #expect(received.value?.event == "Stop")
    }

    @Test func aCopyWhoseSocketFileWasReplacedLeavesTheNewOneWhenItQuits() throws {
        let path = try makeTempDirectory().appendingPathComponent("replaced.sock").path
        let first = SocketServer(socketPath: path, clientReadTimeout: 0.5)
        first.start { _ in nil }
        #expect(Self.wait { FileManager.default.fileExists(atPath: path) })

        // Something else removed the first copy's file (an older build quitting did that), and a new copy bound a
        // fresh socket at the same path.
        try FileManager.default.removeItem(atPath: path)
        let second = SocketServer(socketPath: path, clientReadTimeout: 0.5)
        let received = Box<HookEnvelope?>(nil)
        second.start { envelope in received.value = envelope; return nil }
        defer { second.stop() }
        #expect(Self.wait { FileManager.default.fileExists(atPath: path) })

        first.stop()
        Thread.sleep(forTimeInterval: 0.1)
        #expect(FileManager.default.fileExists(atPath: path))

        _ = try runHookScript(socketPath: path, provider: "claude", input: Self.stopEvent)
        #expect(Self.wait { received.value != nil })
        #expect(received.value?.event == "Stop")
    }

    /// Polls until `condition` holds or `timeout` passes; true when it held.
    private static func wait(timeout: TimeInterval = 2, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() > deadline { return false }
            Thread.sleep(forTimeInterval: 0.02)
        }
        return true
    }
}
