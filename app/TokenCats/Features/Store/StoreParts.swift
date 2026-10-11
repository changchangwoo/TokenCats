import SwiftUI

/// A purchase waiting for "구매" in the confirmation.
struct PendingPurchase: Identifiable {
    let product: StoreService.Product
    let name: LocalizedStringResource
    let price: Int
    var id: String {
        switch product {
        case .catBox: return "catBox"
        case .background(let id): return "background-\(id)"
        case .prop(let prop): return "prop-\(prop.rawValue)"
        }
    }
}

/// The one action for an offer: in use and short are shown but disabled; the price comes first.
struct StoreOfferButton: View {
    let offer: OfferState
    let name: LocalizedStringResource
    let theme: RoomTheme
    let busy: Bool
    var affordableTitle: LocalizedStringResource? = nil
    var shortTitle: LocalizedStringResource? = nil
    let action: () -> Void

    var body: some View {
        let title: LocalizedStringResource
        let enabled: Bool
        switch offer {
        case .inUse: (title, enabled) = ("In use", false)
        case .owned: (title, enabled) = ("Owned", false)
        case .affordable(let price):
            (title, enabled) = (affordableTitle ?? "Buy · \(StoreFormat.short(price))", !busy)
        case .short(let price, _): (title, enabled) = (shortTitle ?? "Buy · \(StoreFormat.short(price))", false)
        }
        return Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle((enabled ? theme.surface : theme.ink).swiftUI)
                .padding(.horizontal, 14).padding(.vertical, 7)
                .background(Capsule().fill(enabled ? theme.accent.swiftUI : theme.surface.swiftUI))
                .opacity(enabled ? 1 : 0.75)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(Text("\(name) \(title)" as LocalizedStringResource))
    }
}

/// The adoption box as a picture.
struct StoreBoxArt: View {
    let theme: RoomTheme
    let size: CGFloat

    var body: some View {
        Image(systemName: "shippingbox.fill")
            .resizable().scaledToFit()
            .padding(size * 0.2)
            .foregroundStyle(theme.previewInk.swiftUI)
            .frame(width: size, height: size)
            .background(RoundedRectangle(cornerRadius: 10).fill(theme.preview.swiftUI))
    }
}

/// How store dialogs come and go, so the dim and the card move together.
enum StoreDialogMotion {
    static let animation = Animation.smooth(duration: 0.24)
}

/// A small card over a dimmed store, for confirmations and what a purchase gave. The dim fades with the dialog's
/// transition; the card settles in with a light spring on top of it.
struct StoreDialog<Content: View>: View {
    let theme: RoomTheme
    @ViewBuilder let content: () -> Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var settled = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
            VStack(spacing: 8, content: content)
                .foregroundStyle(theme.ink.swiftUI)
                .padding(16)
                .frame(minWidth: 220)
                .background(RoundedRectangle(cornerRadius: 12).fill(theme.surface.swiftUI))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(theme.panelHighlight.swiftUI, lineWidth: 1))
                .scaleEffect(settled || reduceMotion ? 1 : 0.92)
                .offset(y: settled || reduceMotion ? 0 : 6)
        }
        .onAppear { withAnimation(.spring(duration: 0.34, bounce: 0.28)) { settled = true } }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
    }
}
