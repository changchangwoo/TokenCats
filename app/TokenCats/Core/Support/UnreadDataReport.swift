import Foundation

/// Data files the app could not read and moved aside (`JSONFile.load` renames them `name.corrupt-<seconds>.json`)
/// before starting them fresh. The app tells the user once, so a reset to one cat and no churu is never silent.
enum UnreadDataReport {
    /// The original names ("cats.json") of files moved aside after `after`, sorted and without repeats.
    static func files(in directory: URL, after: Date) -> [String] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        let moved = names.compactMap { name -> String? in
            guard name.hasSuffix(".json"), let marker = name.range(of: ".corrupt-") else { return nil }
            let stamp = name[marker.upperBound...].dropLast(".json".count)
            guard let seconds = TimeInterval(stamp), seconds > after.timeIntervalSince1970 else { return nil }
            return name[..<marker.lowerBound] + ".json"
        }
        return Array(Set(moved)).sorted()
    }
}
