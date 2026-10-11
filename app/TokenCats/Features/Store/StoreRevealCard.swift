import SwiftUI

/// What a purchase gave: the new cat out of its box, or a background or prop now owned.
struct StoreRevealCard: View {
    let result: PurchaseResult
    let theme: RoomTheme
    let household: CatHousehold
    let onClose: () -> Void
    let onOpenCats: () -> Void
    @Environment(\.locale) private var locale

    var body: some View {
        StoreDialog(theme: theme) {
            switch result {
            case .adopted(let cat, let tier):
                BoxOpening(icon: CatFace(coat: cat.coat))
                Text("\(CatNames.display(cat, in: household).text) · \(tier.name.resolve(for: locale))" as LocalizedStringResource)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                Text(cat.inRoom ? "Moved into the room" : "The room is full, so it waits in the collection")
                    .font(.system(size: 11, design: .rounded))
                Button("OK", action: onClose).keyboardShortcut(.defaultAction)
            case .backgroundOwned(let id):
                ItemPop {
                    RoomPreview(theme: RoomThemeCatalog.bundled.backgrounds.first { $0.id == id }?.theme ?? theme)
                        .frame(width: 168, height: 63)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                Text("Bought the \(RoomThemeCatalog.bundled.backgrounds.first { $0.id == id }?.name.resolve(for: locale) ?? id) background" as LocalizedStringResource)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                Text("Apply it from the collection")
                    .font(.system(size: 11, design: .rounded)).opacity(0.75)
                HStack {
                    Button("Close", action: onClose)
                    Button("Open collection", action: onOpenCats)
                        .keyboardShortcut(.defaultAction)
                }
            case .propOwned(let prop):
                ItemPop {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8).fill(theme.preview.swiftUI)
                        if let art = prop.art, let image = RoomArtImages.image(art.image) {
                            Image(nsImage: image).resizable().interpolation(.none).scaledToFit()
                                .frame(maxWidth: Double(art.width), maxHeight: Double(art.height))
                                .padding(6)
                        }
                    }
                    .frame(width: 104, height: 76)
                }
                Text("\(prop.title) purchased" as LocalizedStringResource)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                Text("Place it from the collection")
                    .font(.system(size: 11, design: .rounded)).opacity(0.75)
                HStack {
                    Button("Close", action: onClose)
                    Button("Open collection", action: onOpenCats)
                        .keyboardShortcut(.defaultAction)
                }
            default:
                EmptyView()
            }
        }
    }
}

/// What was bought pops up from small, a beat after the dialog arrives, and settles with a little bounce.
private struct ItemPop<Content: View>: View {
    @ViewBuilder let content: () -> Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    var body: some View {
        content()
            .scaleEffect(shown || reduceMotion ? 1 : 0.5)
            .opacity(shown || reduceMotion ? 1 : 0)
            .task {
                guard !reduceMotion else { return }
                try? await Task.sleep(for: .seconds(0.12))
                withAnimation(.spring(duration: 0.45, bounce: 0.4)) { shown = true }
            }
    }
}

/// The box shakes for a moment, then the cat appears.
private struct BoxOpening<Icon: View>: View {
    let icon: Icon
    @State private var opened = false
    @State private var shake = false

    var body: some View {
        ZStack {
            if opened {
                icon.frame(width: 64, height: 64).transition(.scale.combined(with: .opacity))
            } else {
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 44))
                    .rotationEffect(.degrees(shake ? 8 : -8))
                    .animation(.easeInOut(duration: 0.12).repeatCount(6, autoreverses: true), value: shake)
            }
        }
        .frame(height: 70)
        .task {
            shake = true
            try? await Task.sleep(for: .seconds(0.8))
            withAnimation(.spring(duration: 0.35)) { opened = true }
        }
    }
}
