import SwiftUI

/// The screen title and churu on hand; only detail pages show a back button.
struct ScreenHeader: View {
    let theme: RoomTheme
    let back: LocalizedStringKey?
    let title: LocalizedStringKey
    let onBack: () -> Void
    @ObservedObject private var churu = ChuruModel.shared
    @ObservedObject private var store = StoreModel.shared

    var body: some View {
        HStack(spacing: 8) {
            if let back {
                Button(action: onBack) {
                    Label(back, systemImage: "chevron.left")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                }
                .buttonStyle(.plain)
                .foregroundStyle(theme.ink.swiftUI.opacity(0.8))
            }
            Text(title)
                .font(.system(size: 15, weight: .heavy, design: .rounded))
            if store.isFreeForTesting {
                Text("Testing · free")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.surface.swiftUI)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Capsule().fill(theme.accent.swiftUI))
            }
            Spacer()
            if store.busy { ProgressView().controlSize(.small) }
            Image(systemName: "fish.fill").foregroundStyle(theme.accent.swiftUI)
            LoadingValue(text: churu.snapshot.map { TokenCount.compact($0.balance) })
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .monospacedDigit()
            Text("churu").font(.system(size: 11, weight: .bold, design: .rounded))
        }
        .foregroundStyle(theme.ink.swiftUI)
    }
}

/// A cat's resting icon in its pixel art, or a plain cat symbol when the coat has no art.
struct CatFace: View {
    let coat: String

    var body: some View {
        Group {
            if let image = CatSprites.shared.portrait(coat: coat) {
                Image(decorative: image, scale: 1).interpolation(.none).resizable().scaledToFit()
            } else {
                Image(systemName: "cat.fill").resizable().scaledToFit()
            }
        }
    }
}

/// The store's and My Cats' surface: the theme's base colour, rounded like Home.
struct ScreenFrame<Content: View>: View {
    let theme: RoomTheme
    @ViewBuilder let content: Content

    var body: some View {
        content
            .foregroundStyle(theme.ink.swiftUI)
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(theme.panel.swiftUI)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 12)
            .padding(.bottom, 6)
    }
}
