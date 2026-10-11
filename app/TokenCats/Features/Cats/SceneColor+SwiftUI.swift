import Combine
import SwiftUI

extension SceneColor {
    var swiftUI: Color {
        Color(.sRGB, red: Double(red) / 255, green: Double(green) / 255, blue: Double(blue) / 255, opacity: opacity)
    }
}
