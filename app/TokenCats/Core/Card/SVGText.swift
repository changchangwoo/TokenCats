import Foundation

/// Small helpers for writing SVG by hand.
enum SVGText {
    /// Escapes text for an element body or attribute value.
    static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    /// One 1×1 `<rect>` per marked cell of a pixel map, for icons drawn as dots.
    static func pixels(_ rows: [String], mark: Character) -> String {
        var out = ""
        for (row, line) in rows.enumerated() {
            for (column, pixel) in line.enumerated() where pixel == mark {
                out += #"<rect x="\#(column)" y="\#(row)" width="1" height="1"/>"#
            }
        }
        return out
    }
}
