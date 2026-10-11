import Foundation

/// POSIX single-quoting for paths placed in commands that agents run through `sh -c`.
enum ShellQuote {
    static func quote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: #"'\''"#) + "'"
    }
}
