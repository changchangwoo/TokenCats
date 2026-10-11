import Foundation

struct CommandResult: Sendable {
    let status: Int32
    let stdout: String
}

protocol CommandRunner: Sendable {
    func run(_ executable: String, _ arguments: [String]) -> CommandResult
}

struct SystemCommandRunner: CommandRunner {
    func run(_ executable: String, _ arguments: [String]) -> CommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return CommandResult(status: -1, stdout: "")
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return CommandResult(status: process.terminationStatus, stdout: String(decoding: data, as: UTF8.self))
    }
}
