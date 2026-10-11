import SwiftUI

/// The TokenCats paw (`BrandPaw`) drawn pixel for pixel, the same mark the profile card puts by its name.
struct PixelPaw: View {
    let color: Color
    var size: CGFloat = 16

    var body: some View {
        Canvas { graphics, canvas in
            let cell = canvas.width / CGFloat(BrandPaw.rows.count)
            for (row, line) in BrandPaw.rows.enumerated() {
                for (column, mark) in line.enumerated() where mark == "o" {
                    graphics.fill(Path(CGRect(x: CGFloat(column) * cell, y: CGFloat(row) * cell, width: cell, height: cell)),
                                  with: .color(color))
                }
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
