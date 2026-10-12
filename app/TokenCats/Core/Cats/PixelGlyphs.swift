import Foundation

/// 3 × 5 pixel letters and digits, shared by the wall calendar's month name and the profile card's level tags.
/// English and fixed width, so the card looks the same everywhere.
enum PixelGlyphs {
    static let glyphs: [Character: [String]] = [
        "A": [".X.", "X.X", "XXX", "X.X", "X.X"], "B": ["XX.", "X.X", "XX.", "X.X", "XX."],
        "C": [".XX", "X..", "X..", "X..", ".XX"], "D": ["XX.", "X.X", "X.X", "X.X", "XX."],
        "E": ["XXX", "X..", "XX.", "X..", "XXX"], "F": ["XXX", "X..", "XX.", "X..", "X.."],
        "G": [".XX", "X..", "X.X", "X.X", ".XX"], "J": ["..X", "..X", "..X", "X.X", ".X."],
        "L": ["X..", "X..", "X..", "X..", "XXX"], "M": ["X.X", "XXX", "XXX", "X.X", "X.X"],
        "N": ["XX.", "X.X", "X.X", "X.X", "X.X"], "O": [".X.", "X.X", "X.X", "X.X", ".X."],
        "P": ["XX.", "X.X", "XX.", "X..", "X.."], "R": ["XX.", "X.X", "XX.", "X.X", "X.X"],
        "S": [".XX", "X..", ".X.", "..X", "XX."], "T": ["XXX", ".X.", ".X.", ".X.", ".X."],
        "U": ["X.X", "X.X", "X.X", "X.X", "XXX"], "V": ["X.X", "X.X", "X.X", "X.X", ".X."],
        "Y": ["X.X", "X.X", ".X.", ".X.", ".X."],
        "0": ["XXX", "X.X", "X.X", "X.X", "XXX"], "1": [".X.", "XX.", ".X.", ".X.", "XXX"],
        "2": ["XXX", "..X", "XXX", "X..", "XXX"], "3": ["XXX", "..X", "XXX", "..X", "XXX"],
        "4": ["X.X", "X.X", "XXX", "..X", "..X"], "5": ["XXX", "X..", "XXX", "..X", "XXX"],
        "6": ["XXX", "X..", "XXX", "X.X", "XXX"], "7": ["XXX", "..X", "..X", "..X", "..X"],
        "8": ["XXX", "X.X", "XXX", "X.X", "XXX"], "9": ["XXX", "X.X", "XXX", "..X", "XXX"],
    ]
    static let glyphWidth = 3
    static let glyphHeight = 5
    /// A space is one blank column; a character without a glyph is drawn as one too.
    static let spaceWidth = 1
    /// Pixels between characters.
    static let gap = 1

    private static func advance(_ character: Character) -> Int {
        glyphs[character] == nil ? spaceWidth : glyphWidth
    }

    /// Width in pixels: each character's columns plus one gap between characters.
    static func width(of text: String) -> Int {
        guard !text.isEmpty else { return 0 }
        return text.reduce(0) { $0 + advance($1) } + (text.count - 1) * gap
    }

    /// One rect per horizontal run of lit pixels, left to right one row at a time per character, starting at
    /// (`left`, `top`). Spaces and unknown characters only advance.
    static func rects(_ text: String, left: Int, top: Int, color: SceneColor) -> [ScenePixelRect] {
        var rects: [ScenePixelRect] = []
        var x = left
        for character in text {
            defer { x += advance(character) + gap }
            guard let rows = glyphs[character] else { continue }
            for (row, line) in rows.enumerated() {
                var column = 0
                let marks = Array(line)
                while column < marks.count {
                    guard marks[column] == "X" else { column += 1; continue }
                    let start = column
                    while column < marks.count, marks[column] == "X" { column += 1 }
                    rects.append(ScenePixelRect(x: x + start, y: top + row, width: column - start, height: 1,
                                                color: color))
                }
            }
        }
        return rects
    }
}
