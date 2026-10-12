import SwiftUI

/// The bar under a level: how far into the current level, in the theme's accent over its lowest level colour,
/// the same pair the adoption progress bar uses. Every level costs the same, so the bar fills at one speed.
struct BondBar: View {
    let progress: Double
    let theme: RoomTheme

    var body: some View {
        Capsule().fill(theme.levels[0].swiftUI)
            .overlay(alignment: .leading) {
                GeometryReader { geometry in
                    Capsule().fill(theme.accent.swiftUI).frame(width: geometry.size.width * min(1, max(0, progress)))
                }
            }
            .frame(height: 3)
            .animation(.smooth(duration: 0.3), value: progress)
    }
}

/// `♥ Lv.N` and its bar, shown above the cat under the pointer. Laid out for `Lv.99` so the bar never shifts when
/// the number changes.
struct BondBadge: View {
    let level: Int
    let progress: Double
    let theme: RoomTheme

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "heart.fill")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Color(red: 0.96, green: 0.28, blue: 0.46))
            Text("Lv.\(level)")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .monospacedDigit()
                .frame(minWidth: 30, alignment: .leading)
            BondBar(progress: progress, theme: theme)
                .frame(width: 44)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(Capsule().fill(.black.opacity(0.55)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Bond level \(level)"))
    }
}
